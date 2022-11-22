//
//  FirestoreViewContext.swift
//  
//
//  Created by Alex Nagy on 22.11.2022.
//

import Foundation
import FirebaseFirestore

public struct FirestoreViewContext<T: Codable & Firestorable & Equatable> {
    
    @discardableResult
    public static func read(_ document: T, collectionPath: String) async throws -> T {
        let reference = Firestore.firestore().collection(collectionPath)
        return try await reference.document(document.uid).getDocument(as: T.self)
    }
    
    @discardableResult
    public static func create(_ document: T, collectionPath: String) throws -> T {
        var reference: DocumentReference
        if document.uid != "" {
            reference = Firestore.firestore().collection(collectionPath).document(document.uid)
            try reference.setData(from: document)
            return document
        } else {
            reference = Firestore.firestore().collection(collectionPath).document()
            var updatedDocument = document
            updatedDocument.uid = reference.documentID
            try reference.setData(from: updatedDocument)
            return updatedDocument
        }
    }
    
    @discardableResult
    public static func update(_ document: T, collectionPath: String) throws -> T {
        let reference = Firestore.firestore().collection(collectionPath)
        try reference.document(document.uid).setData(from: document, merge: true)
        return document
    }
    
    @discardableResult
    public static func delete(_ document: T, collectionPath: String) throws -> T {
        let reference = Firestore.firestore().collection(collectionPath)
        Task {
            try await reference.document(document.uid).delete()
        }
        return document
    }
}
