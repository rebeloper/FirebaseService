//
//  FirestoreFetch.swift
//  
//
//  Created by Alex Nagy on 22.11.2022.
//

import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

/// A property wrapper that fetches a Firestore collection.
/// 
/// import SwiftUI
/// import FirebaseFirestore
/// import FirebaseService
///
/// struct ContentView: View {
///
///     @FirestorePaginatedFetch("posts", pagination: .init(orderBy: "timestamp", descending: false, limit: 3)) /// private var posts: [Post]
/// //    @FirestoreFetch(collectionPath: "posts", predicates: [.orderBy("timestamp", false)]) private var posts: /// [Post]
///
///     var body: some View {
///
///         if let error = _posts.configuration.error {
///             Text(error.localizedDescription)
///                 .foregroundColor(.gray)
///                 .font(.caption)
///         } else {
///             VStack {
///                 if posts.isEmpty {
///                     ProgressView()
///                 } else {
///                     List {
///                         ForEach(posts.indices, id: \.self) { index in
///                             let post = posts[index]
///                             VStack(alignment: .leading) {
///                                 Text(post.value)
///                                 Text(post.uid)
///                                     .font(.caption)
///                                     .foregroundColor(.gray)
///                                     .bold()
///                                 Text("\(post.timestamp.dateValue().formatted(.dateTime))")
///                                     .font(.caption)
///                                     .foregroundColor(.gray)
///                             }
///                             .swipeActions(edge: .leading, allowsFullSwipe: true) {
///                                 Button {
///                                     update(post)
///                                 } label: {
///                                     Image(systemName: "pencil")
///                                 }
///                             }
///                             .onAppear {
///                                 fetchNext(index)
///                             }
///                         }
///                         .onDelete(perform: delete)
///                     }
///                     .refreshable {
///                         refresh()
///                     }
///                 }
///             }
///             .toolbar {
///                 ToolbarItem {
///                     Button {
///                         create()
///                     } label: {
///                         Image(systemName: "plus")
///                     }
///                 }
///             }
///         }
///     }
///
///     func delete(indexSet: IndexSet) {
///         for index in indexSet {
///             delete(posts[index])
///         }
///     }
///
///     func create() {
///         do {
///             try animated {
///                 let post = Post(value: "New post", timestamp: Timestamp(date: Date()))
///                 try _posts.manager.create(post, sortedBy: { p0, p1 in
///                     p0.timestamp.dateValue() < p1.timestamp.dateValue()
///                 })
///             }
///         } catch {
///             print(error.localizedDescription)
///         }
///     }
///
///     func delete(_ post: Post) {
///         do {
///             try _posts.manager.delete(post)
///         } catch {
///             print(error.localizedDescription)
///         }
///     }
///
///     func update(_ post: Post) {
///         var newPost = post
///         newPost.value = "Updated post"
///         do {
///             try _posts.manager.update(post, with: newPost, sortedBy: { p0, p1 in
///                 p0.timestamp.dateValue() < p1.timestamp.dateValue()
///             })
///         } catch {
///             print(error.localizedDescription)
///         }
///     }
///
///     func fetchNext(_ index: Int) {
///         if index % 3 == 0 {
///             _posts.manager.fetch()
///         }
///     }
///
///     func refresh() {
///         _posts.manager.refresh()
///     }
/// }
///
/// struct Post: Codable, Firestorable, Equatable,  Hashable {
///     var uid = UUID().uuidString
///     var value: String
///     var timestamp: Timestamp
/// }
///
@propertyWrapper
public struct FirestoreFetch<T>: DynamicProperty {
    @StateObject public var manager: FirestoreFetchManager<T>
    
    /// The query's configurable properties.
    public struct Configuration {
        /// The query's collection path.
        public var path: String
        
        /// The query's predicates.
        public var predicates: [QueryPredicate]
        
        // The strategy to use in case there was a problem during the decoding phase.
        public var decodingFailureStrategy: DecodingFailureStrategy = .raise
        
        /// If any errors occurred, they will be exposed here as well.
        public var error: Error?
    }
    
    public var wrappedValue: T {
        get {
            manager.value
        }
        nonmutating set {
            manager.value = newValue
        }
    }
    
    public var projectedValue: Binding<T> {
        Binding(
            get: {
                wrappedValue
            },
            set: {
                wrappedValue = $0
            }
        )
    }
    
    /// A binding to the request's mutable configuration properties
    public var configuration: Configuration {
        get {
            manager.configuration
        }
        nonmutating set {
            manager.objectWillChange.send()
            manager.configuration = newValue
        }
    }
    
    /// Creates an instance by defining a query based on the parameters.
    /// - Parameters:
    ///   - collectionPath: The path to the Firestore collection to query.
    ///   - predicates: An optional array of `QueryPredicate`s that defines a
    ///     filter for the fetched results.
    ///   - decodingFailureStrategy: The strategy to use when there is a failure
    ///     during the decoding phase. Defaults to `DecodingFailureStrategy.raise`.
    public init<U: Decodable & Hashable>(collectionPath: String,
                                         predicates: [QueryPredicate] = [],
                                         decodingFailureStrategy: DecodingFailureStrategy = .raise) where T == [U] {
        let configuration = Configuration(
            path: collectionPath,
            predicates: predicates,
            decodingFailureStrategy: decodingFailureStrategy
        )
        _manager = StateObject(wrappedValue: FirestoreFetchManager<T>(configuration: configuration))
    }
}

final public class FirestoreFetchManager<T>: ObservableObject {
    
    @Published public var value: T
    
    private let firestore = Firestore.firestore()
    
    private var setupQuery: (() -> Void)!
    
    internal var shouldUpdateQuery = true
    internal var configuration: FirestoreFetch<T>.Configuration {
        didSet {
            // prevent never-ending update cycle when updating the error field
            guard shouldUpdateQuery else { return }
            setupQuery()
        }
    }
    
    public init<U: Decodable & Hashable>(configuration: FirestoreFetch<T>.Configuration) where T == [U] {
        self.value = [U]()
        self.configuration = configuration
        
        fetch()
    }
    
    /// Fetches the values.
    public func fetch<U: Decodable & Hashable>() where T == [U] {
        setupQuery = createQuery { [weak self] result in
            switch result {
            case .success(let querySnapshot):
                guard let documents = querySnapshot?.documents else {
                    withAnimation {
                        self?.value = []
                    }
                    return
                }
                
                let decodedDocuments: [U] = documents.compactMap { queryDocumentSnapshot in
                    let result = Result { try queryDocumentSnapshot.data(as: U.self) }
                    switch result {
                    case let .success(decodedDocument):
                        return decodedDocument
                    case let .failure(error):
                        self?.projectError(error)
                        return nil
                    }
                }
                
                if self?.configuration.error != nil {
                    if self?.configuration.decodingFailureStrategy == .raise {
                        withAnimation {
                            self?.value = []
                        }
                    } else {
                        withAnimation {
                            self?.value = decodedDocuments
                        }
                    }
                } else {
                    withAnimation {
                        self?.value = decodedDocuments
                    }
                }
                
            case .failure(let error):
                withAnimation {
                    self?.value = []
                    self?.projectError(error)
                }
            }
        }
        setupQuery()
    }
    
    private func getQuery() -> Query {
        var query: Query = self.firestore.collection(self.configuration.path)
        
        for predicate in self.configuration.predicates {
            switch predicate {
            case let .isEqualTo(field, value):
                query = query.whereField(field, isEqualTo: value)
            case let .isIn(field, values):
                query = query.whereField(field, in: values)
            case let .isNotIn(field, values):
                query = query.whereField(field, notIn: values)
            case let .arrayContains(field, value):
                query = query.whereField(field, arrayContains: value)
            case let .arrayContainsAny(field, values):
                query = query.whereField(field, arrayContainsAny: values)
            case let .isLessThan(field, value):
                query = query.whereField(field, isLessThan: value)
            case let .isGreaterThan(field, value):
                query = query.whereField(field, isGreaterThan: value)
            case let .isLessThanOrEqualTo(field, value):
                query = query.whereField(field, isLessThanOrEqualTo: value)
            case let .isGreaterThanOrEqualTo(field, value):
                query = query.whereField(field, isGreaterThanOrEqualTo: value)
            case let .orderBy(field, value):
                query = query.order(by: field, descending: value)
            case let .limitTo(field):
                query = query.limit(to: field)
            case let .limitToLast(field):
                query = query.limit(toLast: field)
            }
        }
        return query
    }
    
    private func createQuery(with completion: @escaping (Result<QuerySnapshot?, Error>) -> Void)
    -> () -> Void {
        return {
            self.getQuery().getDocuments { querySnapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                completion(.success(querySnapshot))
            }
        }
    }
    
    private func projectError(_ error: Error?) {
        shouldUpdateQuery = false
        configuration.error = error
        shouldUpdateQuery = true
    }
    
    /// Creates a new element.
    /// - Parameters:
    ///   - element: An element to be created.
    ///   - areInIncreasingOrder: Order of the value being fetched.
    public func create<U: Codable & Firestorable & Equatable & Hashable>(_ element: U, sortedBy areInIncreasingOrder: ((U, U) throws -> Bool)? = nil) throws where T == [U] {
        try animated {
            try value.append(element, collectionPath: configuration.path, sortedBy: areInIncreasingOrder)
        }
    }
    
    /// Deletes an element.
    /// - Parameter element: The element to be deleted.
    public func delete<U: Codable & Firestorable & Equatable & Hashable>(_ element: U) throws where T == [U] {
        try animated {
            try value.delete(element, collectionPath: configuration.path)
        }
    }
    
    /// Updates an element.
    /// - Parameters:
    ///   - element: An element to be updated.
    ///   - newElement: The updated element.
    ///   - areInIncreasingOrder: Order of the value being fetched.
    public func update<U: Codable & Firestorable & Equatable & Hashable>(_ element: U, with newElement: U, sortedBy areInIncreasingOrder: ((U, U) throws -> Bool)? = nil) throws where T == [U] {
        try animated {
            try value.update(element, with: newElement, collectionPath: configuration.path)
        }
    }
}

