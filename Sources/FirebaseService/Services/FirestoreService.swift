//
//  FirestoreService.swift
//  
//
//  Created by Alex Nagy on 20.04.2021.
//

import SwiftUI
import Firebase

public class FirestoreService<T: Codable & Firestorable> {
    
    public static func create(_ document: T, atPath path: String, completion: @escaping (Result<T, Error>) -> ()) {
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
    
    public static func create(_ document: T, withUid uid: String, atPath path: String, completion: @escaping (Result<T, Error>) -> ()) {
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
    
    public static func createIfNonExistent(_ document: T, withUid uid: String, atPath path: String, completion: @escaping (Result<T, Error>) -> ()) {
        
        FirestoreService.read(atPath: path, uid: uid) { (result) in
            switch result {
            case .success(let document):
                completion(.success(document))
            case .failure(let err):
                if let error = err as? FirebaseError, error == FirebaseError.documentDoesNotExist {
                    FirestoreService.create(document, withUid: uid, atPath: path, completion: completion)
                } else {
                    completion(.failure(err))
                }
            }
        }
    }
    
    public static func read(atPath path: String, uid: String, completion: @escaping (Result<T, Error>) -> ()) {
        let reference = Firestore.firestore().collection(path).document(uid)
        FirestoreDecoder<T>.getCodable(for: reference, completion: completion)
    }
    
    public static func update(_ document: T, withUid uid: String, atPath path: String, completion: @escaping (Result<T, Error>) -> Void = {_ in}) {
        do {
            try Firestore.firestore().collection(path).document(uid).setData(from: document, merge: true)
            completion(.success(document))
        } catch {
            completion(.failure(error))
        }
    }
    
    public static func delete(_ document: T, atPath path: String, completion: @escaping (Result<Bool, Error>) -> Void = {_ in}) {
        Firestore.firestore().collection(path).document(document.uid).delete { error in
            if let error = error {
                completion(.failure(error))
            }
            completion(.success(true))
        }
    }
    
    public static func query(_ query: Query, completion: @escaping (Result<[T], Error>) -> ()) {
        FirestoreDecoder<T>.getCodables(for: query, completion: completion)
    }
    
    public static func listen(to query: Query, completion: @escaping (Result<[T], Error>) -> Void = {_ in}) {
        FirestoreDecoder<T>.listen(to: query, completion: completion)
    }
    
}


