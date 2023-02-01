//
//  FirestoreContext.swift
//  
//
//  Created by Alex Nagy on 22.11.2022.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

public struct FirestoreContext<T: Codable & Firestorable & Equatable> {
    
    /// Reads a document from a Firestore collection.
    /// - Parameters:
    ///   - uid: The uid of the document to be read.
    ///   - collectionPath: The collection path of the document.
    @discardableResult public static func read(_ uid: String, collectionPath: String) async throws -> T {
        let reference = Firestore.firestore().collection(collectionPath)
        return try await reference.document(uid).getDocument(as: T.self)
    }
    
    /// Reads a document from a Firestore collection.
    /// - Parameters:
    ///   - uid: The uid of the document to be read.
    ///   - collectionPath: The collection path of the document.
    @discardableResult public static func query(collectionPath: String, predicates: [QueryPredicate]) async throws -> [T] {
        var query: Query = getQuery(path: collectionPath, predicates: predicates)
        let snapshot = try await query.getDocuments()
        let documents = snapshot.documents.compactMap { document in
            try? document.data(as: T.self)
        }
        return documents
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
                    if error._code == 4865 {
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
    
    private static func getQuery(path: String, predicates: [QueryPredicate]) -> Query {
        var query: Query = Firestore.firestore().collection(path)
        
        for predicate in predicates {
            switch predicate {
            case let .isEqualTo(field, value):
                query = query.whereField(field, isEqualTo: value)
            case let .isIn(field, values):
                query = query.whereField(field, in: values)
            case let .isNotIn(field, values):
                query = query.whereField(field, notIn: values)
            case let .arrayContains(field, value):
                query = query.whereField(field, arrayContains: value)
            case let .arrayContainsAny(field, values):
                query = query.whereField(field, arrayContainsAny: values)
            case let .isLessThan(field, value):
                query = query.whereField(field, isLessThan: value)
            case let .isGreaterThan(field, value):
                query = query.whereField(field, isGreaterThan: value)
            case let .isLessThanOrEqualTo(field, value):
                query = query.whereField(field, isLessThanOrEqualTo: value)
            case let .isGreaterThanOrEqualTo(field, value):
                query = query.whereField(field, isGreaterThanOrEqualTo: value)
            case let .orderBy(field, value):
                query = query.order(by: field, descending: value)
            case let .limitTo(field):
                query = query.limit(to: field)
            case let .limitToLast(field):
                query = query.limit(toLast: field)
            }
        }
        return query
    }
}
