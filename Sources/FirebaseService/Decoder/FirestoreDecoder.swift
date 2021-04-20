//
//  FirestoreDecoder.swift
//  
//
//  Created by Alex Nagy on 20.04.2021.
//

import Firebase
import FirebaseFirestoreSwift

public struct FirestoreDecoder<T: Codable> {
    
    public static func getCodable(for reference: DocumentReference, completion: @escaping (Result<T, Error>) -> ()) {
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
    
    public static func getCodables(for query: Query, completion: @escaping (Result<[T], Error>) -> ()) {
        query.getDocuments { (querySnapshot, err) in
            if let err = err {
                completion(.failure(err))
                return
            }
            guard let querySnapshot = querySnapshot else {
                completion(.failure(FirebaseError.noQuerySnapshot))
                return
            }
            let documents = querySnapshot.documents
            
            var objects = [T]()
            for document in documents {
                let result = Result {
                    try document.data(as: T.self)
                }
                switch result {
                case .success(let object):
                    if let object = object {
                        objects.append(object)
                    } else {
                        print("documentDoesNotExist")
                    }
                case .failure(let err):
                    print(err.localizedDescription)
                }
            }
            completion(.success(objects))
        }
    }
    
    public static func listen(to query: Query, completion: @escaping (Result<[T], Error>) -> Void = {_ in}) {
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
}

