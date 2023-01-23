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
    
    @EnvironmentObject public var context: FirebaseAuthenticatorContext<Profile>
    
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
            context.credentials
        }
        nonmutating set {
            context.credentials = newValue
        }
    }
    
    public init() { }
}

public struct FireabseAutheticatorView<Content: View, Profile: Codable & Firestorable & Equatable>: View {
    
    @StateObject private var authState: AuthState
    @StateObject public var context: FirebaseAuthenticatorContext<Profile>
    @ViewBuilder public var content: () -> Content
    
    public init(_ profileCollectionPath: String, shouldLogoutUponLaunch: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        _authState = StateObject(wrappedValue: AuthState(shouldLogoutUponLaunch: shouldLogoutUponLaunch))
        let configuration = FirebaseAuthenticator<Profile>.Configuration(path: profileCollectionPath)
        _context = StateObject(wrappedValue: FirebaseAuthenticatorContext<Profile>(configuration: configuration))
        self.content = content
    }
    
    public var body: some View {
        content()
            .environmentObject(authState)
            .environmentObject(context)
    }
}

@MainActor
final public class FirebaseAuthenticatorContext<Profile: Codable & Firestorable & Equatable>: ObservableObject {
    
    public struct Credentials {
        public var email: String
        public var password: String
    }
    
    @Published public var credentials: Credentials = .init(email: "", password: "")
    
    internal var configuration: FirebaseAuthenticator<Profile>.Configuration
    
    @Published public var profile: Profile? = nil
    @Published public var user: User? = nil
    @Published public var value: AuthenticationStateValue = .undefined
    @Published public var currentUserUid: String? = nil
    @Published public var email: String = ""
    
    public var handle: AuthStateDidChangeListenerHandle?
    
    public init(configuration: FirebaseAuthenticator<Profile>.Configuration, shouldLogoutUponLaunch: Bool = false) {
        self.configuration = configuration
        startAuthListener()
        logoutIfNeeded(shouldLogoutUponLaunch)
    }
    
    private func removeStateDidChangeListener() {
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    private func startAuthListener() {
        removeStateDidChangeListener()
        handle = Auth.auth().addStateDidChangeListener({ auth, user in
            self.user = user
            self.currentUserUid = user?.uid
            self.email = user?.email ?? ""
            self.value = user != nil ? .authenticated : .notAuthenticated
            if let uid = user?.uid {
                Task {
                    do {
                        try await self.fetchProfile(with: uid)
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
        })
    }
    
    private func logoutIfNeeded(_ shouldLogoutUponLaunch: Bool) {
        if shouldLogoutUponLaunch {
            Task {
                print("AuthState: logging out upon launch...")
                do {
                    try signOut()
                    print("Logged out")
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
    }
    
    public func fetchProfile(with uid: String) async throws {
        self.profile = try await FirestoreContext.read(uid, collectionPath: configuration.path)
    }
    
    public func signUp(profile: Profile) async throws {
        let authDataResult = try await Auth.auth().createUser(withEmail: credentials.email, password: credentials.password)
        var profile = profile
        profile.uid = authDataResult.user.uid
        self.profile = try await FirestoreContext.create(profile, collectionPath: configuration.path, ifNonExistent: true)
    }
    
    @discardableResult
    public func signIn() async throws -> AuthDataResult {
        try await Auth.auth().signIn(withEmail: credentials.email, password: credentials.password)
    }
    
    public func signOut() throws {
        try Auth.auth().signOut()
    }
    
    public func sendPasswordResetEmail() async throws {
        try await Auth.auth().sendPasswordReset(withEmail: credentials.email)
    }
}

