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
    
}

