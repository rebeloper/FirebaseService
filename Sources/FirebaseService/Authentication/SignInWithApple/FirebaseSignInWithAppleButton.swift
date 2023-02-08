//
//  FirebaseSignInWithAppleButton.swift
//  
//
//  Created by Alex Nagy on 20.04.2021.
//

import SwiftUI
import AuthenticationServices
import FirebaseAuth

public struct FirebaseSignInWithAppleButton<Profile: Codable & Firestorable & Nameable & Equatable>: View {
    
    private var label: SignInWithAppleButton.Label
    private var requestedScopes: [ASAuthorization.Scope]?
    private var onCompletion: ((Result<Profile, Error>) -> Void)
    
    @State private var currentNonce: String? = nil
    
    @Binding public var profile: Profile
    
    @EnvironmentObject private var authenticator: FirebaseAuthenticator<Profile>
    
    public init(label: SignInWithAppleButton.Label = .signIn, requestedScopes: [ASAuthorization.Scope]? = [.fullName, .email], profile: Binding<Profile>, onCompletion: @escaping ((Result<Profile, Error>) -> Void) = {_ in}) {
        self.label = label
        self.requestedScopes = requestedScopes
        self._profile = profile
        self.onCompletion = onCompletion
    }
    
    public var body: some View {
        SignInWithAppleButton(label) { (request) in
            request.requestedScopes = requestedScopes
            let nonce = FirebaseSignInWithAppleUtils.randomNonceString()
            currentNonce = nonce
            request.nonce = FirebaseSignInWithAppleUtils.sha256(nonce)
        } onCompletion: { (result) in
            switch result {
            case .success(let authorization):
                FirebaseSignInWithAppleUtils.createToken(from: authorization, currentNonce: currentNonce) { result in
                    switch result {
                    case .success(let firebaseSignInWithAppleResult):
                        guard var profile = self.authenticator.profile else { return }
                        profile.uid = firebaseSignInWithAppleResult.uid
                        profile.firstName = firebaseSignInWithAppleResult.token.appleIDCredential.fullName?.givenName ?? ""
                        profile.middleName = firebaseSignInWithAppleResult.token.appleIDCredential.fullName?.middleName ?? ""
                        profile.lastName = firebaseSignInWithAppleResult.token.appleIDCredential.fullName?.familyName ?? ""
                        onCompletion(.success(profile))
                    case .failure(let error):
                        onCompletion(.failure(error))
                    }
                }
            case .failure(let error):
                onCompletion(.failure(error))
            }
        }
        .onChange(of: profile) { newValue in
            authenticator.profile = profile
        }
    }
    
}
