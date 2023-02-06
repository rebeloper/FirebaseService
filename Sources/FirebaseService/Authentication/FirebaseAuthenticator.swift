//
//  FirebaseAuthenticator.swift
//  
//
//  Created by Alex Nagy on 19.01.2023.
//

import SwiftUI
import FirebaseAuth
import AuthenticationServices

public struct FirebaseAuthenticatorView<Content: View, Profile: Codable & Firestorable & Nameable & Equatable>: View {
    
    @StateObject public var authenticator: FirebaseAuthenticator<Profile>
    @ViewBuilder public var content: () -> Content
    
    public init(_ profileCollectionPath: String, shouldLogoutUponLaunch: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        let configuration = FirebaseAuthenticator<Profile>.Configuration(path: profileCollectionPath)
        _authenticator = StateObject(wrappedValue: FirebaseAuthenticator<Profile>(configuration: configuration))
        self.content = content
    }
    
    public var body: some View {
        content()
            .environmentObject(authenticator)
    }
}

final public class FirebaseAuthenticator<Profile: Codable & Firestorable & Nameable & Equatable>: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    public struct Configuration {
        public var path: String
    }
    
    public struct Credentials {
        public var email: String
        public var password: String
    }
    
    @Published public var credentials: Credentials = .init(email: "", password: "")
    
    internal var configuration: Configuration
    
    @Published public var profile: Profile? = nil
    @Published public var user: User? = nil
    @Published public var value: AuthenticationStateValue = .undefined
    @Published public var currentUserUid: String? = nil
    @Published public var email: String = ""
    
    public var handle: AuthStateDidChangeListenerHandle?
    
    public init(configuration: Configuration, shouldLogoutUponLaunch: Bool = false) {
        self.configuration = configuration
        super.init()
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
    

    // MARK: - Sign in with Apple
    
    private var onContinueWithApple: ((Result<Profile, Error>) -> ())? = nil
    
    fileprivate var currentNonce: String?
    
    public func continueWithApple(profile: Profile) async throws {
        let profile = try await withCheckedThrowingContinuation({ continuation in
            continueWithApple(profile: profile) { result in
                continuation.resume(with: result)
            }
        })
        self.profile = try await FirestoreContext.create(profile, collectionPath: configuration.path, ifNonExistent: true)
    }
    
    private func continueWithApple(profile: Profile, onContinueWithApple: @escaping (Result<Profile, Error>) -> ()) {
        
        self.profile = profile
        self.onContinueWithApple = onContinueWithApple
        
        let nonce = FirebaseSignInWithAppleUtils.randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = FirebaseSignInWithAppleUtils.sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    // MARK: - ASAuthorizationControllerDelegate
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        FirebaseSignInWithAppleUtils.createToken(from: authorization, currentNonce: currentNonce) { result in
            switch result {
            case .success(let firebaseSignInWithAppleResult):
                guard var profile = self.profile else { return }
                profile.uid = firebaseSignInWithAppleResult.uid
                profile.firstName = firebaseSignInWithAppleResult.token.appleIDCredential.fullName?.givenName ?? ""
                profile.middleName = firebaseSignInWithAppleResult.token.appleIDCredential.fullName?.middleName ?? ""
                profile.lastName = firebaseSignInWithAppleResult.token.appleIDCredential.fullName?.familyName ?? ""
                self.onContinueWithApple?(.success(profile))
            case .failure(let error):
                self.onContinueWithApple?(.failure(error))
            }
        }
    }
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onContinueWithApple?(.failure(error))
    }
    
    // MARK: - ASAuthorizationControllerPresentationContextProviding
    
#if os(iOS)
    public var window: UIWindow? {
        guard let scene = UIApplication.shared.connectedScenes.first,
              let windowSceneDelegate = scene.delegate as? UIWindowSceneDelegate,
              let window = windowSceneDelegate.window else {
            return nil
        }
        return window
    }
    
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.window!
    }
#endif
    
#if os(macOS)
    public var window: NSWindow? {
        guard let window = NSApplication.shared.keyWindow else {
            return nil
        }
        return window
    }
    
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.window!
    }
#endif
}

