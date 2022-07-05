//
//  FirestoreManager.swift
//  
//
//  Created by Alex Nagy on 05.07.2022.
//

import Combine
import FirebaseFirestore

public var firestoreManagerCancellables: Set<AnyCancellable> = []

public class FirestoreManager<T: Codable & Firestorable> {
    
    @MainActor
    @discardableResult
    public static func create(_ document: T, atPath path: String) async throws -> T {
        try await AsyncPromise.fulfill(FirestoreService.create(document, atPath: path), storedIn: &firestoreManagerCancellables)
    }
    
    @MainActor
    @discardableResult
    public static func create(_ document: T, withUid uid: String, atPath path: String) async throws -> T {
        try await AsyncPromise.fulfill(FirestoreService.create(document, withUid: uid, atPath: path), storedIn: &firestoreManagerCancellables)
    }
    
    @MainActor
    @discardableResult
    public static func read(atPath path: String, uid: String) async throws -> T {
        try await AsyncPromise.fulfill(FirestoreService.read(atPath: path, uid: uid), storedIn: &firestoreManagerCancellables)
    }
    
    @MainActor
    @discardableResult
    public static func read(atPath path: String) async throws -> [T] {
        try await AsyncPromise.fulfill(FirestoreService.read(atPath: path), storedIn: &firestoreManagerCancellables)
    }
    
    @MainActor
    @discardableResult
    public static func update(_ document: T, withUid uid: String, atPath path: String) async throws -> T {
        try await AsyncPromise.fulfill(FirestoreService.update(document, withUid: uid, atPath: path), storedIn: &firestoreManagerCancellables)
    }
    
    @MainActor
    @discardableResult
    public static func update(_ document: T, atPath path: String) async throws -> T {
        try await AsyncPromise.fulfill(FirestoreService.update(document, atPath: path), storedIn: &firestoreManagerCancellables)
    }
    
    @MainActor
    @discardableResult
    public static func delete(atPath path: String, withUid uid: String) async throws -> Bool {
        try await AsyncPromise.fulfill(FirestoreService<T>.delete(atPath: path, withUid: uid), storedIn: &firestoreManagerCancellables)
    }
    
    @MainActor
    @discardableResult
    public static func delete(_ document: T, atPath path: String) async throws -> Bool {
        try await AsyncPromise.fulfill(FirestoreService.delete(document, atPath: path), storedIn: &firestoreManagerCancellables)
    }
    
    @MainActor
    @discardableResult
    public static func query(_ query: Query) async throws -> [T] {
        try await AsyncPromise.fulfill(FirestoreService.query(query), storedIn: &firestoreManagerCancellables)
    }
    
    @MainActor
    @discardableResult
    public static func query(path: String, queryItems: [QueryItem]? = nil, queryLimit: QueryLimit? = nil) async throws -> [T] {
        try await AsyncPromise.fulfill(FirestoreService.query(path: path, queryItems: queryItems, queryLimit: queryLimit), storedIn: &firestoreManagerCancellables)
    }
    
    @MainActor
    @discardableResult
    public static func listen(to query: Query) -> PassthroughSubject<[T], Error> {
        FirestoreService.listen(to: query)
    }
    
    @MainActor
    @discardableResult
    public static func listenTo(_ path: String, queryItems: [QueryItem]? = nil) -> PassthroughSubject<[T], Error> {
        FirestoreService.listenTo(path, queryItems: queryItems)
    }
    
    @MainActor
    @discardableResult
    public static func createIfNonExistent(_ document: T, withUid uid: String, atPath path: String) async throws -> T {
        try await AsyncPromise.fulfill(FirestoreService.createIfNonExistent(document, withUid: uid, atPath: path), storedIn: &firestoreManagerCancellables)
    }
}
