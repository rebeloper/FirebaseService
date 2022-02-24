//
//  FirestoreService.swift
//  
//
//  Created by Alex Nagy on 20.04.2021.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine
import SwiftUI

public enum QueryItemType {
    case isEqualTo, isNotEqualTo, isLessThan, isLessThanOrEqualTo, isGreaterThan, isGreaterThanOrEqualTo, arrayContains, arrayContainsAny, `in`, notIn
}

public struct QueryItem {
    public let key: String
    public let type: QueryItemType
    public let values: [Any]
    
    public init(_ key: String,
                _ type: QueryItemType,
                _ value: Any) {
        self.key = key
        self.type = type
        self.values = [value]
    }
    
    public init(_ key: String,
                _ type: QueryItemType,
                _ values: [Any]) {
        self.key = key
        self.type = type
        self.values = values
    }
}

public struct QueryLimit {
    public var limit: Int
    public var orderBy: String
    public var descending: Bool
    @Binding public var lastDocumentSnapshot: DocumentSnapshot?
    
    public init(limit: Int,
         orderBy: String,
         descending: Bool,
         lastDocumentSnapshot: Binding<DocumentSnapshot?>) {
        self.limit = limit
        self.orderBy = orderBy
        self.descending = descending
        self._lastDocumentSnapshot = lastDocumentSnapshot
    }
}

public class FirestoreService<T: Codable & Firestorable> {
    
    //CRUDQL
    
    // MARK: - Public
    
    public static func create(_ document: T, atPath path: String) -> Future<T, Error> {
        return Future<T, Error> { completion in
            setData(document, atPath: path, completion: completion)
        }
    }
    
    public static func create(_ document: T, withUid uid: String, atPath path: String) -> Future<T, Error> {
        return Future<T, Error> { completion in
            setData(document, withUid: uid, atPath: path, completion: completion)
        }
    }
    
    public static func read(atPath path: String, uid: String) -> Future<T, Error> {
        let reference = Firestore.firestore().collection(path).document(uid)
        return FirestoreDecoder<T>.getCodable(for: reference)
    }
    
    public static func read(atPath path: String) -> Future<[T], Error> {
        let reference = Firestore.firestore().collection(path)
        return FirestoreDecoder<T>.getCodables(for: reference)
    }
    
    public static func update(_ document: T, withUid uid: String, atPath path: String) -> Future<T, Error> {
        return Future<T, Error> { completion in
            do {
                try Firestore.firestore().collection(path).document(uid).setData(from: document, merge: true)
                completion(.success(document))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    public static func update(_ document: T, atPath path: String) -> Future<T, Error> {
        return update(document, withUid: document.uid, atPath: path)
    }
    
    public static func delete(atPath path: String, withUid uid: String) -> Future<Bool, Error> {
        return Future<Bool, Error> { completion in
            Firestore.firestore().collection(path).document(uid).delete { error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                completion(.success(true))
            }
        }
    }
    
    public static func delete(_ document: T, atPath path: String) -> Future<Bool, Error> {
        return delete(atPath: path, withUid: document.uid)
    }
    
    public static func query(_ query: Query) -> Future<[T], Error> {
        FirestoreDecoder<T>.getCodables(for: query)
    }
    
    public static func query(base query: Query, limit: Int, orderBy: String, descending: Bool, lastDocumentSnapshot: Binding<DocumentSnapshot?>) -> Future<[T], Error> {
        var theQuery = query
        if lastDocumentSnapshot.wrappedValue != nil {
            theQuery = query
                .limit(to: limit)
                .order(by: orderBy, descending: descending)
                .start(afterDocument: lastDocumentSnapshot.wrappedValue!)
        } else {
            theQuery = query
                .limit(to: limit)
                .order(by: orderBy, descending: descending)
        }
        return FirestoreDecoder<T>.getCodables(for: theQuery, lastDocumentSnapshot: lastDocumentSnapshot)
    }
    
    public static func query(base query: Query, items: [QueryItem], limit: QueryLimit) -> Future<[T], Error> {
        
        var queryWithQueryItems = query
        var queryWithLimitAndOrder = queryWithQueryItems
        
        items.forEach { queryItem in
            
            let key = queryItem.key
            let type = queryItem.type
            let values = queryItem.values
            
            guard let value = values.first else { return }
            
            switch type {
            case .isEqualTo:
                queryWithQueryItems = query.whereField(key, isEqualTo: value)
                
            case .isNotEqualTo:
                queryWithQueryItems = query.whereField(key, isNotEqualTo: value)
                
            case .isLessThan:
                queryWithQueryItems = query.whereField(key, isLessThan: value)
                
            case .isLessThanOrEqualTo:
                queryWithQueryItems = query.whereField(key, isLessThanOrEqualTo: value)
                
            case .isGreaterThan:
                queryWithQueryItems = query.whereField(key, isGreaterThan: value)
                
            case .isGreaterThanOrEqualTo:
                queryWithQueryItems = query.whereField(key, isGreaterThanOrEqualTo: value)
                
            case .arrayContains:
                queryWithQueryItems = query.whereField(key, arrayContains: values)
                
            case .arrayContainsAny:
                queryWithQueryItems = query.whereField(key, arrayContainsAny: values)
                
            case .in:
                queryWithQueryItems = query.whereField(key, in: values)
                
            case .notIn:
                queryWithQueryItems = query.whereField(key, notIn: values)
                
            }
            
            if limit.lastDocumentSnapshot != nil {
                queryWithLimitAndOrder = queryWithQueryItems
                    .limit(to: limit.limit)
                    .order(by: limit.orderBy, descending: limit.descending)
                    .start(afterDocument: limit.lastDocumentSnapshot!)
            } else {
                queryWithLimitAndOrder = queryWithQueryItems
                    .limit(to: limit.limit)
                    .order(by: limit.orderBy, descending: limit.descending)
            }
        }
        
        return FirestoreDecoder<T>.getCodables(for: queryWithLimitAndOrder, lastDocumentSnapshot: limit.$lastDocumentSnapshot)
        
    }
    
    public static func query(base query: Query, queryItem: QueryItem, limit: Int, orderBy: String, descending: Bool, lastDocumentSnapshot: Binding<DocumentSnapshot?>) -> Future<[T], Error> {
        
        let key = queryItem.key
        let type = queryItem.type
        let values = queryItem.values
        
        var theQuery = query
        switch type {
        case .isEqualTo:
            guard let value = values.first else {
                return Future<[T], Error> { completion in
                    completion(.failure(FirebaseError.noQueryItemValuesFirstValue))
                }
            }
            if lastDocumentSnapshot.wrappedValue != nil {
                theQuery = query
                    .whereField(key, isEqualTo: value)
                    .limit(to: limit)
                    .order(by: orderBy, descending: descending)
                    .start(afterDocument: lastDocumentSnapshot.wrappedValue!)
            } else {
                theQuery = query
                    .whereField(key, isEqualTo: value)
                    .limit(to: limit)
                    .order(by: orderBy, descending: descending)
            }
        case .isNotEqualTo:
            guard let value = values.first else {
                return Future<[T], Error> { completion in
                    completion(.failure(FirebaseError.noQueryItemValuesFirstValue))
                }
            }
            if lastDocumentSnapshot.wrappedValue != nil {
                theQuery = query
                    .whereField(key, isNotEqualTo: value)
                    .limit(to: limit)
                    .order(by: orderBy, descending: descending)
                    .start(afterDocument: lastDocumentSnapshot.wrappedValue!)
            } else {
                theQuery = query
                    .whereField(key, isNotEqualTo: value)
                    .limit(to: limit)
                    .order(by: orderBy, descending: descending)
            }
        case .isLessThan:
            guard let value = values.first else {
                return Future<[T], Error> { completion in
                    completion(.failure(FirebaseError.noQueryItemValuesFirstValue))
                }
            }
            if lastDocumentSnapshot.wrappedValue != nil {
                theQuery = query
                    .whereField(key, isLessThan: value)
                    .limit(to: limit)
                    .order(by: orderBy, descending: descending)
                    .start(afterDocument: lastDocumentSnapshot.wrappedValue!)
            } else {
                theQuery = query
                    .whereField(key, isLessThan: value)
                    .limit(to: limit)
                    .order(by: orderBy, descending: descending)
            }
        case .isLessThanOrEqualTo:
            guard let value = values.first else {
                return Future<[T], Error> { completion in
                    completion(.failure(FirebaseError.noQueryItemValuesFirstValue))
                }
            }
            if lastDocumentSnapshot.wrappedValue != nil {
                theQuery = query
                    .whereField(key, isLessThanOrEqualTo: value)
                    .limit(to: limit)
                    .order(by: orderBy, descending: descending)
                    .start(afterDocument: lastDocumentSnapshot.wrappedValue!)
            } else {
                theQuery = query
                    .whereField(key, isLessThanOrEqualTo: value)
                    .limit(to: limit)
                    .order(by: orderBy, descending: descending)
            }
        case .isGreaterThan:
            guard let value = values.first else {
                return Future<[T], Error> { completion in
                    completion(.failure(FirebaseError.noQueryItemValuesFirstValue))
                }
            }
            if lastDocumentSnapshot.wrappedValue != nil {
                theQuery = query
                    .whereField(key, isGreaterThan: value)
                    .limit(to: limit)
                    .order(by: orderBy, descending: descending)
                    .start(afterDocument: lastDocumentSnapshot.wrappedValue!)
            } else {
                theQuery = query
                    .whereField(key, isGreaterThan: value)
                    .limit(to: limit)
                    .order(by: orderBy, descending: descending)
            }
        case .isGreaterThanOrEqualTo:
            guard let value = values.first else {
                return Future<[T], Error> { completion in
                    completion(.failure(FirebaseError.noQueryItemValuesFirstValue))
                }
            }
            if lastDocumentSnapshot.wrappedValue != nil {
                theQuery = query
                    .whereField(key, isGreaterThanOrEqualTo: value)
                    .limit(to: limit)
                    .order(by: orderBy, descending: descending)
                    .start(afterDocument: lastDocumentSnapshot.wrappedValue!)
            } else {
                theQuery = query
                    .whereField(key, isGreaterThanOrEqualTo: value)
                    .limit(to: limit)
                    .order(by: orderBy, descending: descending)
            }
        case .arrayContains:
            guard values.count != 0 else {
                return Future<[T], Error> { completion in
                    completion(.failure(FirebaseError.noQueryItemValues))
                }
            }
            if lastDocumentSnapshot.wrappedValue != nil {
                theQuery = query
                    .whereField(key, arrayContains: values)
                    .limit(to: limit)
                    .order(by: orderBy, descending: descending)
                    .start(afterDocument: lastDocumentSnapshot.wrappedValue!)
            } else {
                theQuery = query
                    .whereField(key, arrayContains: values)
                    .limit(to: limit)
                    .order(by: orderBy, descending: descending)
            }
        case .arrayContainsAny:
            guard values.count != 0 else {
                return Future<[T], Error> { completion in
                    completion(.failure(FirebaseError.noQueryItemValues))
                }
            }
            if lastDocumentSnapshot.wrappedValue != nil {
                theQuery = query
                    .whereField(key, arrayContainsAny: values)
                    .limit(to: limit)
                    .order(by: orderBy, descending: descending)
                    .start(afterDocument: lastDocumentSnapshot.wrappedValue!)
            } else {
                theQuery = query
                    .whereField(key, arrayContainsAny: values)
                    .limit(to: limit)
                    .order(by: orderBy, descending: descending)
            }
        case .in:
            guard values.count != 0 else {
                return Future<[T], Error> { completion in
                    completion(.failure(FirebaseError.noQueryItemValues))
                }
            }
            if lastDocumentSnapshot.wrappedValue != nil {
                theQuery = query
                    .whereField(key, in: values)
                    .limit(to: limit)
                    .order(by: orderBy, descending: descending)
                    .start(afterDocument: lastDocumentSnapshot.wrappedValue!)
            } else {
                theQuery = query
                    .whereField(key, in: values)
                    .limit(to: limit)
                    .order(by: orderBy, descending: descending)
            }
        case .notIn:
            guard values.count != 0 else {
                return Future<[T], Error> { completion in
                    completion(.failure(FirebaseError.noQueryItemValues))
                }
            }
            if lastDocumentSnapshot.wrappedValue != nil {
                theQuery = query
                    .whereField(key, notIn: values)
                    .limit(to: limit)
                    .order(by: orderBy, descending: descending)
                    .start(afterDocument: lastDocumentSnapshot.wrappedValue!)
            } else {
                theQuery = query
                    .whereField(key, notIn: values)
                    .limit(to: limit)
                    .order(by: orderBy, descending: descending)
            }
        }
        return FirestoreDecoder<T>.getCodables(for: theQuery, lastDocumentSnapshot: lastDocumentSnapshot)
    }
    
    public static func listen(to query: Query) -> PassthroughSubject<[T], Error> {
        FirestoreDecoder<T>.listen(to: query)
    }
    
    public static func createIfNonExistent(_ document: T, withUid uid: String, atPath path: String) -> Future<T, Error> {
        return Future<T, Error> { completion in
            let reference = Firestore.firestore().collection(path).document(uid)
            FirestoreDecoder<T>.getDocument(reference: reference) { result in
                switch result {
                case .success(let document):
                    completion(.success(document))
                case .failure(let err):
                    if let error = err as? FirebaseError, error.code == FirebaseError.documentDoesNotExist.code {
                        setData(document, withUid: uid, atPath: path, completion: completion)
                    } else {
                        completion(.failure(err))
                    }
                }
            }
        }
    }
    
    // MARK: - Private
    
    private static func setData(_ document: T, withUid uid: String? = nil, atPath path: String, completion: @escaping (Result<T, Error>) -> ()) {
        do {
            var newDocument = document
            var reference: DocumentReference
            if let uid = uid {
                reference = Firestore.firestore().collection(path).document(uid)
                newDocument.uid = uid
            } else {
                reference = Firestore.firestore().collection(path).document()
                newDocument.uid = reference.documentID
            }
            try reference.setData(from: newDocument)
            completion(.success(newDocument))
        } catch {
            completion(.failure(error))
        }
    }
    
}

