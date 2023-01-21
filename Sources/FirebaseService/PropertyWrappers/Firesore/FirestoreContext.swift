//
//  FirestoreContext.swift
//  
//
//  Created by Alex Nagy on 22.11.2022.
//

import Foundation
import FirebaseFirestore

public struct FirestoreContext<T: Codable & Firestorable & Equatable> {
    
    /// Reads a document from a Firestore collection.
    /// - Parameters:
    ///   - uid: The uid of the document to be read.
    ///   - collectionPath: The collection path of the document.
    @discardableResult public static func read(_ uid: String, collectionPath: String) async throws -> T {
        let reference = Firestore.firestore().collection(collectionPath)
        return try await reference.document(uid).getDocument(as: T.self)
    }
    
    /// Creates a Firestore document at a collection path.
    /// - Parameters:
    ///   - document: The docuemnt to be created.
    ///   - collectionPath: The collection path of the document.
    @discardableResult public static func create(_ document: T, collectionPath: String, ifNonExistent: Bool = false) async throws -> T {
        var reference: DocumentReference
        if document.uid != "" {
            reference = Firestore.firestore().collection(collectionPath).document(document.uid)
            if ifNonExistent {
                do {
                    let document = try await read(document.uid, collectionPath: collectionPath)
                    return document
                } catch {
                    print(error)
                    print(error._code)
                    if error._code == 1234 {
                        try reference.setData(from: document)
                        return document
                    } else {
                        throw error
                    }
                }
            } else {
                try reference.setData(from: document)
                return document
            }
        } else {
            reference = Firestore.firestore().collection(collectionPath).document()
            var updatedDocument = document
            updatedDocument.uid = reference.documentID
            try reference.setData(from: updatedDocument)
            return updatedDocument
        }
    }
    
    /// Updates a Firestore document at a collection path.
    /// - Parameters:
    ///   - document: The document to be updated.
    ///   - collectionPath: The collection path of the document.
    @discardableResult public static func update(_ document: T, collectionPath: String) throws -> T {
        let reference = Firestore.firestore().collection(collectionPath)
        try reference.document(document.uid).setData(from: document, merge: true)
        return document
    }
    
    /// Deletes a document for a Firestore collection.
    /// - Parameters:
    ///   - document: The the document to be deleted.
    ///   - collectionPath: The collection path of the document.
    @discardableResult public static func delete(_ document: T, collectionPath: String) throws -> T {
        let reference = Firestore.firestore().collection(collectionPath)
        Task {
            try await reference.document(document.uid).delete()
        }
        return document
    }
}
