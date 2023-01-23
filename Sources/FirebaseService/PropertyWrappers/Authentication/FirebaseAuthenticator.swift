//
//  FirebaseAuthenticator.swift
//  
//
//  Created by Alex Nagy on 19.01.2023.
//

import SwiftUI
import FirebaseAuth

@propertyWrapper
public struct FirebaseAuthenticator<Profile: Codable & Firestorable & Equatable>: DynamicProperty {
    
    @StateObject public var context: FirebaseAuthenticatorContext<Profile>
    
    public struct Configuration {
        public var path: String
    }
    
    public var configuration: Configuration {
        get {
            context.configuration
        }
        nonmutating set {
            context.objectWillChange.send()
            context.configuration = newValue
        }
    }
    
    public var wrappedValue: FirebaseAuthenticatorContext<Profile>.Credentials {
        get {
            context.value
        }
        nonmutating set {
            context.value = newValue
        }
    }
    
    public init(_ path: String) {
        let configuration = Configuration(path: path)
        _context = StateObject(wrappedValue: FirebaseAuthenticatorContext<Profile>(configuration: configuration))
    }
}

@MainActor
final public class FirebaseAuthenticatorContext<Profile: Codable & Firestorable & Equatable>: ObservableObject {
    
    public struct Credentials {
        public var email: String
        public var password: String
    }
    
    @Published public var value: Credentials = .init(email: "", password: "")
    
    internal var configuration: FirebaseAuthenticator<Profile>.Configuration
    
    public init(configuration: FirebaseAuthenticator<Profile>.Configuration) {
        self.configuration = configuration
    }
    
    public func signUp(profile: Profile) async throws {
        let authDataResult = try await Auth.auth().createUser(withEmail: value.email, password: value.password)
        var profile = profile
        profile.uid = authDataResult.user.uid
        try await FirestoreContext.create(profile, collectionPath: configuration.path, ifNonExistent: true)
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

