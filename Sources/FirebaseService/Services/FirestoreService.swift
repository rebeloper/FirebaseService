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
    
    public static func query(path: String, limit: Int, orderBy: String, descending: Bool, lastDocumentSnapshot: Binding<DocumentSnapshot?>) -> Future<[T], Error> {
        var query: Query = Firestore.firestore().collection(path)
        if lastDocumentSnapshot.wrappedValue != nil {
            query = Firestore.firestore()
                .collection(path)
                .limit(to: limit)
                .order(by: orderBy, descending: descending)
                .start(afterDocument: lastDocumentSnapshot.wrappedValue!)
        } else {
            query = Firestore.firestore()
                .collection(path)
                .limit(to: limit)
                .order(by: orderBy, descending: descending)
        }
        return FirestoreDecoder<T>.getCodables(for: query, lastDocumentSnapshot: lastDocumentSnapshot)
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

