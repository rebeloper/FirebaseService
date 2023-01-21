//
//  FirestoreDocument.swift
//  
//
//  Created by Alex Nagy on 21.01.2023.
//

import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

/// A property wrapper that fetches a Firestore document.
@propertyWrapper
public struct FirestoreDocument<U: Codable & Firestorable & Equatable>: DynamicProperty {
    @StateObject public var context: FirestoreDocumentContext<U>
    
    /// The query's configurable properties.
    public struct Configuration {
        /// The query's collection path.
        public var path: String
        
        /// The document's uid
        public var uid: String
        
        // The strategy to use in case there was a problem during the decoding phase.
        public var decodingFailureStrategy: DecodingFailureStrategy = .raise
        
        /// If any errors occurred, they will be exposed here as well.
        public var error: Error?
        
    }
    
    public var wrappedValue: U? {
        get {
            context.value
        }
        nonmutating set {
            context.value = newValue
        }
    }
    
    public var projectedValue: Binding<U?> {
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
            context.configuration
        }
        nonmutating set {
            context.objectWillChange.send()
            context.configuration = newValue
        }
    }
    
    /// Creates an instance by defining a query based on the parameters.
    /// - Parameters:
    ///   - collectionPath: The path to the Firestore collection to query.
    ///   - uid: The `uid` of the document.
    ///   - decodingFailureStrategy: The strategy to use when there is a failure
    ///     during the decoding phase. Defaults to `DecodingFailureStrategy.raise`.
    public init(_ collectionPath: String,
                uid: String,
                decodingFailureStrategy: DecodingFailureStrategy = .raise) {
        let configuration = Configuration(
            path: collectionPath,
            uid: uid,
            decodingFailureStrategy: decodingFailureStrategy
        )
        _context = StateObject(wrappedValue: FirestoreDocumentContext<U>(configuration: configuration))
    }
}

final public class FirestoreDocumentContext<U: Codable & Firestorable & Equatable>: ObservableObject {
    
    @Published public var value: U?
    
    private let firestore = Firestore.firestore()
    
    private var setupQuery: (() -> Void)!
    
    internal var shouldUpdateQuery = true
    internal var configuration: FirestoreDocument<U>.Configuration {
        didSet {
            // prevent never-ending update cycle when updating the error field
            guard shouldUpdateQuery else { return }
            setupQuery()
        }
    }
    
    public init(configuration: FirestoreDocument<U>.Configuration) {
        self.configuration = configuration
        fetch()
    }
    
    /// Fetches the values.
    public func fetch() {
        setupQuery = createQuery { [weak self] result in
            switch result {
            case .success(let documentSnapshot):
                guard let documentSnapshot = documentSnapshot else {
                    withAnimation {
                        self?.value = nil
                    }
                    return
                }
                
                do {
                    let decodedDocument: U = try documentSnapshot.data(as: U.self)
                    
                    if self?.configuration.error != nil {
                        if self?.configuration.decodingFailureStrategy == .raise {
                            withAnimation {
                                self?.value = nil
                            }
                        } else {
                            withAnimation {
                                self?.value = decodedDocument
                            }
                        }
                    } else {
                        withAnimation {
                            self?.value = decodedDocument
                        }
                    }
                } catch {
                    withAnimation {
                        self?.value = nil
                        self?.projectError(error)
                    }
                }
                
            case .failure(let error):
                withAnimation {
                    self?.value = nil
                    self?.projectError(error)
                }
            }
        }
        setupQuery()
    }
    
    private func createQuery(with completion: @escaping (Result<DocumentSnapshot?, Error>) -> Void)
    -> () -> Void {
        return {
            self.firestore.collection(self.configuration.path).document(self.configuration.uid).getDocument { documentSnapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                completion(.success(documentSnapshot))
            }
        }
    }
    
    private func projectError(_ error: Error?) {
        shouldUpdateQuery = false
        configuration.error = error
        shouldUpdateQuery = true
    }
    
    /// Deletes an element.
    /// - Parameter element: The element to be deleted.
    public func delete(_ element: U) throws {
        try FirestoreContext.delete(element, collectionPath: configuration.path)
    }
    
    /// Updates an element.
    /// - Parameters:
    ///   - element: The updated element.
    public func update(_ element: U) throws {
        try FirestoreContext.update(element, collectionPath: configuration.path)
    }
}

