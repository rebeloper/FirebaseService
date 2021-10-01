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

public class FirestoreService<T: Codable & Firestorable> {
    
    //CRUDQL
    
    public static func create(_ document: T, atPath path: String) -> Future<T, Error> {
        return Future<T, Error> { completion in
            do {
                var newDocument = document
                let reference = Firestore.firestore().collection(path).document()
                let uid = reference.documentID
                newDocument.uid = uid
                try reference.setData(from: newDocument)
                completion(.success(newDocument))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    public static func create(_ document: T, withUid uid: String, atPath path: String) -> Future<T, Error> {
        return Future<T, Error> { completion in
            do {
                var newDocument = document
                newDocument.uid = uid
                let reference = Firestore.firestore().collection(path).document(uid)
                try reference.setData(from: newDocument)
                completion(.success(newDocument))
            } catch {
                completion(.failure(error))
            }
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
    
    public static func delete(_ document: T, withUid uid: String, atPath path: String) -> Future<Bool, Error> {
        return Future<Bool, Error> { completion in
            Firestore.firestore().collection(path).document(document.uid).delete { error in
                if let error = error {
                    completion(.failure(error))
                }
                completion(.success(true))
            }
        }
    }
    
    public static func query(_ query: Query) -> Future<[T], Error> {
        FirestoreDecoder<T>.getCodables(for: query)
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
                        do {
                            var newDocument = document
                            newDocument.uid = uid
                            let reference = Firestore.firestore().collection(path).document(uid)
                            try reference.setData(from: newDocument)
                            completion(.success(newDocument))
                        } catch {
                            completion(.failure(error))
                        }
                    } else {
                        completion(.failure(err))
                    }
                }
            }
        }
    }
    
    public static func batchSet(_ batchDocuments: [BatchDocument<T>]) -> Future<[T], Error> {
        return Future<[T], Error> { completion in
            
            var newDocuments: [T] = []
            
            let batch = Firestore.firestore().batch()
            
            for i in 0..<batchDocuments.count {
                var newDocument = batchDocuments[i].document
                let path = batchDocuments[i].path
                let merge = batchDocuments[i].merge
                
                var reference: DocumentReference
                if merge {
                    reference = Firestore.firestore().collection(path).document()
                    let uid = reference.documentID
                    newDocument.uid = uid
                } else {
                    reference = Firestore.firestore().collection(path).document(newDocument.uid)
                }
                
                do {
                    try batch.setData(from: newDocument, forDocument: reference, merge: merge)
                    newDocuments.append(newDocument)
                } catch {
                    completion(.failure(error))
                }
            }
            
            batch.commit { err in
                if let err = err {
                    completion(.failure(err))
                    return
                }
                completion(.success(newDocuments))
            }
        }
    }
    
}

