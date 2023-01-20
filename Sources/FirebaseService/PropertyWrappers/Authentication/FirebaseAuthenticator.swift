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
        var email: String
        var password: String
    }
    
    @Published public var value: Credentials = .init(email: "", password: "")
    
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
}

