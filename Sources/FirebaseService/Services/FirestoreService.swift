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
    
    public static func query(path: String, queryItems: [QueryItem]? = nil, queryLimit: QueryLimit? = nil) -> Future<[T], Error> {
        
        var query: Query = Firestore.firestore().collection(path)
        query = add(queryItems: queryItems, to: query)
        
        if queryLimit != nil {
            let queryLimit = queryLimit!
            if queryLimit.lastDocumentSnapshot != nil {
                query = query
                    .limit(to: queryLimit.limit)
                    .order(by: queryLimit.orderBy, descending: queryLimit.descending)
                    .start(afterDocument: queryLimit.lastDocumentSnapshot!)
            } else {
                query = query
                    .limit(to: queryLimit.limit)
                    .order(by: queryLimit.orderBy, descending: queryLimit.descending)
            }
            return FirestoreDecoder<T>.getCodables(for: query, lastDocumentSnapshot: queryLimit.$lastDocumentSnapshot)
        } else {
            return FirestoreDecoder<T>.getCodables(for: query)
        }
    }
    
    public static func listen(to query: Query) -> PassthroughSubject<[T], Error> {
        FirestoreDecoder<T>.listen(to: query)
    }
    
    public static func listenTo(_ path: String, queryItems: [QueryItem]? = nil) -> PassthroughSubject<[T], Error> {
        var query: Query = Firestore.firestore().collection(path)
        query = add(queryItems: queryItems, to: query)
        return FirestoreDecoder<T>.listen(to: query)
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
    
    private static func add(queryItems: [QueryItem]?, to query: Query) -> Query {
        var query = query
        if queryItems != nil {
            queryItems!.forEach { queryItem in
                
                let key = queryItem.key
                let type = queryItem.type
                let values = queryItem.values
                
                guard let value = values.first else { return }
                
                switch type {
                case .isEqualTo:
                    query = query.whereField(key, isEqualTo: value)
                case .isNotEqualTo:
                    query = query.whereField(key, isNotEqualTo: value)
                case .isLessThan:
                    query = query.whereField(key, isLessThan: value)
                case .isLessThanOrEqualTo:
                    query = query.whereField(key, isLessThanOrEqualTo: value)
                case .isGreaterThan:
                    query = query.whereField(key, isGreaterThan: value)
                case .isGreaterThanOrEqualTo:
                    query = query.whereField(key, isGreaterThanOrEqualTo: value)
                case .arrayContains:
                    query = query.whereField(key, arrayContains: values)
                case .arrayContainsAny:
                    query = query.whereField(key, arrayContainsAny: values)
                case .in:
                    query = query.whereField(key, in: values)
                case .notIn:
                    query = query.whereField(key, notIn: values)
                }
            }
        }
        return query
    }
    
}
