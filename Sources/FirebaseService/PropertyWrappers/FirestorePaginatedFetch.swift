//
//  FirestorePaginatedFetch.swift
//  
//
//  Created by Alex Nagy on 22.11.2022.
//

import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

@propertyWrapper
public struct FirestorePaginatedFetch<T>: DynamicProperty {
    @StateObject public var manager: FirestorePaginatedFetchManager<T>
    
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
    
    public init<U: Decodable>(_ collectionPath: String,
                              pagination: FirestorePaginatedFetchPagination,
                              predicates: [QueryPredicate] = [],
                              decodingFailureStrategy: DecodingFailureStrategy = .raise) where T == [U] {
        var predicates = predicates
        predicates.append(.order(by: pagination.orderBy, descending: pagination.descending))
        predicates.append(.limit(to: pagination.limit))
        let configuration = Configuration(
            path: collectionPath,
            predicates: predicates,
            decodingFailureStrategy: decodingFailureStrategy
        )
        _manager = StateObject(wrappedValue: FirestorePaginatedFetchManager<T>(configuration: configuration))
    }
}

final public class FirestorePaginatedFetchManager<T>: ObservableObject {
    
    @Published public var value: T
    @Published private var lastDocumentSnapshot: DocumentSnapshot? = nil
    @Published private var didFetchAll = false
    
    private let firestore = Firestore.firestore()
    
    private var fetchQuery: (() -> Void)!
    
    internal var shouldUpdateQuery = true
    internal var configuration: FirestorePaginatedFetch<T>.Configuration {
        didSet {
            // prevent never-ending update cycle when updating the error field
            guard shouldUpdateQuery else { return }
            fetchQuery()
        }
    }
    
    public init<U: Decodable>(configuration: FirestorePaginatedFetch<T>.Configuration) where T == [U] {
        self.value = [U]()
        self.configuration = configuration
        
        fetch()
    }
    
    public func refresh<U: Decodable>() where T == [U] {
        reset()
        fetch()
    }
    
    public func reset<U: Decodable>() where T == [U] {
        didFetchAll = false
        lastDocumentSnapshot = nil
        value = []
    }
    
    public func fetch<U: Decodable>() where T == [U] {
        if didFetchAll {
            print("did fetch all")
            return
        }
        fetchQuery = createQuery { [weak self] result in
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
                            self?.value += decodedDocuments
                        }
                    }
                } else {
                    withAnimation {
                        self?.value += decodedDocuments
                    }
                }
                
            case .failure(let error):
                withAnimation {
                    self?.value = []
                    self?.projectError(error)
                }
            }
        }
        fetchQuery()
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
            self.getSnapshot(query: self.getQuery(), completion: completion)
        }
    }
    
    private func projectError(_ error: Error?) {
        shouldUpdateQuery = false
        configuration.error = error
        shouldUpdateQuery = true
    }
    
    public func getSnapshot(query: Query, completion: @escaping (Result<QuerySnapshot?, Error>) -> ()) {
        var query = query
        if lastDocumentSnapshot != nil {
            query = query.start(afterDocument: lastDocumentSnapshot!)
        }
        
        query.getDocuments { (querySnapshot, err) in
            if let err = err {
                completion(.failure(err))
                return
            }
            guard let querySnapshot = querySnapshot else {
                completion(.success(nil))
                return
            }
            
            if let lastDocument = querySnapshot.documents.last {
                if self.lastDocumentSnapshot == lastDocument {
                    self.didFetchAll = true
                }
                self.lastDocumentSnapshot = lastDocument
            }
            
            completion(.success(querySnapshot))
        }
    }
    
    public func create<U: Codable & Firestorable & Equatable>(_ element: U, sortedBy areInIncreasingOrder: ((U, U) throws -> Bool)? = nil) throws where T == [U] {
        try animated {
            try value.append(element, collectionPath: configuration.path, sortedBy: areInIncreasingOrder)
        }
    }
    
    public func delete<U: Codable & Firestorable & Equatable>(_ element: U) throws where T == [U] {
        try animated {
            try value.delete(element, collectionPath: configuration.path)
        }
    }
    
    public func update<U: Codable & Firestorable & Equatable>(_ element: U, with newElement: U, sortedBy areInIncreasingOrder: ((U, U) throws -> Bool)? = nil) throws where T == [U] {
        try animated {
            try value.update(element, with: newElement, collectionPath: configuration.path)
        }
    }
}
