//
//  FirebaseAuthenticator.swift
//  
//
//  Created by Alex Nagy on 19.01.2023.
//

import SwiftUI
import FirebaseAuth

@propertyWrapper
public struct FirebaseAuthenticator: DynamicProperty {
    
    @StateObject public var context: FirebaseAuthenticatorContext
    
    public var wrappedValue: FirebaseAuthenticatorContext.Credentials {
        get {
            context.value
        }
        nonmutating set {
            context.value = newValue
        }
    }
    
    public init() {
        _context = StateObject(wrappedValue: FirebaseAuthenticatorContext())
    }
}

@MainActor
final public class FirebaseAuthenticatorContext: ObservableObject {
    
    public struct Credentials {
        public var email: String
        public var password: String
        public var name: Name
    }
    
    public struct Name {
        public var first: String
        public var middle: String
        public var last: String
    }
    
    @Published public var value: Credentials = .init(email: "", password: "", name: .init(first: "", middle: "", last: ""))
    
    public init() {
        
    }
    
    @discardableResult
    public func createUser() async throws -> AuthDataResult {
        try await Auth.auth().createUser(withEmail: value.email, password: value.password)
    }
    
    @discardableResult
    public func signIn() async throws -> AuthDataResult {
        try await Auth.auth().signIn(withEmail: value.email, password: value.password)
    }
    
    public func signOut() throws {
        try Auth.auth().signOut()
    }
    
    public func sendPasswordResetEmail() async throws {
        try await Auth.auth().sendPasswordReset(withEmail: value.email)
    }
}

