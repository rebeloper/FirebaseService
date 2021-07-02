//
//  FirestoreDecoder.swift
//  
//
//  Created by Alex Nagy on 20.04.2021.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

public struct FirestoreDecoder<T: Codable> {
    
    public static func getCodable(for reference: DocumentReference) -> Future<T, Error> {
        return Future<T, Error> { completion in
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
    }
    
    public static func getCodables(for query: Query) -> Future<[T], Error> {
        return Future<[T], Error> { completion in
            query.getDocuments { (querySnapshot, err) in
                if let err = err {
                    completion(.failure(err))
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
    }
    
    public static func listen(to query: Query) -> PassthroughSubject<[T], Error> {
        let subject = PassthroughSubject<[T], Error>()
        
        query.addSnapshotListener { querySnapshot, error in
            if let error = error {
                subject.send(completion: .failure(error))
                return
            }
            guard let querySnapshot = querySnapshot else {
                subject.send(completion: .failure(FirebaseError.noQuerySnapshot))
                return
            }
            let documents = querySnapshot.documents.compactMap { document in
                try? document.data(as: T.self)
            }
            subject.send(documents)
        }
        
        return subject
    }
}
