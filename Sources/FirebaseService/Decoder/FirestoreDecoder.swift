//
//  FirestoreDecoder.swift
//  
//
//  Created by Alex Nagy on 20.04.2021.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine
import SwiftUI

public struct FirestoreDecoder<T: Codable> {
    
    public static func getCodable(for reference: DocumentReference) -> Future<T, Error> {
        return Future<T, Error> { completion in
            getDocument(reference: reference, completion: completion)
        }
    }
    
    public static func getCodables(for query: Query, lastDocumentSnapshot: Binding<DocumentSnapshot?>? = nil) -> Future<[T], Error> {
        return Future<[T], Error> { completion in
            getDocuments(query: query, lastDocumentSnapshot: lastDocumentSnapshot, completion: completion)
        }
    }
    
    public static func listen(to query: Query) -> PassthroughSubject<[T], Error> {
        let subject = PassthroughSubject<[T], Error>()
        
        listenToDocuments(query: query) { result in
            switch result {
            case .success(let documents):
                subject.send(documents)
            case .failure(let err):
                subject.send(completion: .failure(err))
            }
        }
        
        return subject
    }
    
    public static func listenToDocuments(query: Query, completion: @escaping (Result<[T], Error>) -> ()) {
        query.addSnapshotListener { querySnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let querySnapshot = querySnapshot else {
                completion(.failure(FirebaseError.noQuerySnapshot))
                return
            }
            let documents = querySnapshot.documents.compactMap { document in
                try? document.data(as: T.self)
            }
            completion(.success(documents))
        }
    }
    
    public static func getDocument(reference: DocumentReference, completion: @escaping (Result<T, Error>) -> ()) {
        reference.getDocument { (documentSnapshot, err) in
            if let err = err {
                completion(.failure(err))
                return
            }
            guard let documentSnapshot = documentSnapshot else {
                completion(.failure(FirebaseError.noDocumentSnapshot))
                return
            }
            if !documentSnapshot.exists {
                completion(.failure(FirebaseError.documentDoesNotExist))
                return
            }
            
            let result = Result {
                try documentSnapshot.data(as: T.self)
            }
            switch result {
            case .success(let object):
                if let object = object {
                    completion(.success(object))
                } else {
                    completion(.failure(FirebaseError.documentDoesNotExist))
                }
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }
    
    public static func getDocuments(query: Query, lastDocumentSnapshot: Binding<DocumentSnapshot?>? = nil, completion: @escaping (Result<[T], Error>) -> ()) {
        query.getDocuments { (querySnapshot, err) in
            if let err = err {
                completion(.failure(err))
                return
            }
            guard let querySnapshot = querySnapshot else {
                completion(.failure(FirebaseError.noQuerySnapshot))
                return
            }
            
            if lastDocumentSnapshot != nil {
                guard let lastDocument = querySnapshot.documents.last else {
                    completion(.failure(FirebaseError.noLastDocumentSnapshot))
                    return
                }
                lastDocumentSnapshot!.wrappedValue = lastDocument
            }
            
            let documents = querySnapshot.documents.compactMap { document in
                try? document.data(as: T.self)
            }
            completion(.success(documents))
        }
    }
}
