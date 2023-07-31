//
//  FirestoreContext.swift
//  
//
//  Created by Alex Nagy on 22.11.2022.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import SwiftUI

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
    ///   - collectionPath: The collection path of the document.
    ///   - predicates: The predicates for the query
    @discardableResult public static func query(collectionPath: String, predicates: [QueryPredicate]) async throws -> [T] {
        let query: Query = getQuery(path: collectionPath, predicates: predicates)
        let snapshot = try await query.getDocuments()
        let documents = snapshot.documents.compactMap { document in
            try? document.data(as: T.self)
        }
        return documents
    }
    
    /// Reads a document from a Firestore collection in a paginated way. Must containe .limitTo and .orderBy predicates.
    /// - Parameters:
    ///   - collectionPath: The collection path of the document.
    ///   - predicates: The predicates for the query
    ///   - lastDocumentSnapshot: The last document snapshot
    @discardableResult public static func query(collectionPath: String, predicates: [QueryPredicate], lastDocumentSnapshot: Binding<DocumentSnapshot?>) async throws -> [T] {
        let query: Query = getQuery(path: collectionPath, predicates: predicates)
        if let lastDocumentSnapshot = lastDocumentSnapshot.wrappedValue {
            print("Last doc snapshot id: \(lastDocumentSnapshot.documentID)")
            query.start(afterDocument: lastDocumentSnapshot)
        }
        let snapshot = try await query.getDocuments()
        let documents = snapshot.documents.compactMap { document in
            try? document.data(as: T.self)
        }
        lastDocumentSnapshot.wrappedValue = snapshot.documents.last
        return documents
    }
    
    /// Creates a Firestore document at a collection path.
    /// - Parameters:
    ///   - document: The docuemnt to be created.
    ///   - collectionPath: The collection path of the document.
    @discardableResult public static func create(_ document: T, collectionPath: String, ifNonExistent: Bool = false) async throws -> T {
        var reference: DocumentReference
        if let uid = document.uid, uid != "" {
            reference = Firestore.firestore().collection(collectionPath).document(uid)
            if ifNonExistent {
                do {
                    let document = try await read(uid, collectionPath: collectionPath)
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
    @discardableResult public static func update(_ document: T, collectionPath: String) throws -> T? {
        guard let uid = document.uid else { return nil }
        let reference = Firestore.firestore().collection(collectionPath)
        try reference.document(uid).setData(from: document, merge: true)
        return document
    }
    
    /// Increases a field value by the amount specified inside a document.
    /// - Parameters:
    ///   - field: The field to be increased.
    ///   - by: The amount to decrease. Defaults to 1.
    ///   - document: The document.
    ///   - collectionPath: The collection path of the document.
    public static func increase(_ field: String, by: Int = 1, forDocument document: T, atCollectionPath collectionPath: String) async throws {
        guard let uid = document.uid else { return }
        guard by > 0 else { return }
        try await Firestore.firestore().collection(collectionPath).document(uid).updateData([
            field: FieldValue.increment(Int64(by))
        ])
    }
    
    // Increases a field value by the amount specified inside a document.
    /// - Parameters:
    ///   - field: The field to be increased.
    ///   - by: The amount to decrease. Defaults to 1.
    ///   - uid: The uid of the document.
    ///   - collectionPath: The collection path of the document.
    public static func increase(_ field: String, by: Int = 1, forUid uid: String, atCollectionPath collectionPath: String) async throws {
        guard by > 0 else { return }
        try await Firestore.firestore().collection(collectionPath).document(uid).updateData([
            field: FieldValue.increment(Int64(by))
        ])
    }
    
    /// Decreases a field value by the amount specified inside a document.
    /// - Parameters:
    ///   - field: The field to be decreased.
    ///   - by: The amount to decrease. Defaults to 1.
    ///   - document: The document.
    ///   - collectionPath: The collection path of the document.
    public static func decrease(_ field: String, by: Int = 1, forDocument document: T, atCollectionPath collectionPath: String) async throws {
        guard let uid = document.uid else { return }
        guard by > 0 else { return }
        try await Firestore.firestore().collection(collectionPath).document(uid).updateData([
            field: FieldValue.increment(Int64(-by))
        ])
    }
    
    /// Decreases a field value by the amount specified inside a document.
    /// - Parameters:
    ///   - field: The field to be decreased.
    ///   - by: The amount to decrease. Defaults to 1.
    ///   - uid: The uid of the document.
    ///   - collectionPath: The collection path of the document.
    public static func decrease(_ field: String, by: Int = 1, forUid uid: String, atCollectionPath collectionPath: String) async throws {
        guard by > 0 else { return }
        try await Firestore.firestore().collection(collectionPath).document(uid).updateData([
            field: FieldValue.increment(Int64(-by))
        ])
    }
    
    /// Deletes a document for a Firestore collection.
    /// - Parameters:
    ///   - document: The the document to be deleted.
    ///   - collectionPath: The collection path of the document.
    @discardableResult public static func delete(_ document: T, collectionPath: String) throws -> T? {
        guard let uid = document.uid else { return nil }
        let reference = Firestore.firestore().collection(collectionPath)
        Task {
            try await reference.document(uid).delete()
        }
        return document
    }
    
    /// Deletes a document for a Firestore collection.
    /// - Parameters:
    ///   - uid: The uid of the document to be deleted.
    ///   - collectionPath: The collection path of the document.
    public static func delete(atUid uid: String, collectionPath: String) throws {
        let reference = Firestore.firestore().collection(collectionPath)
        Task {
            try await reference.document(uid).delete()
        }
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
