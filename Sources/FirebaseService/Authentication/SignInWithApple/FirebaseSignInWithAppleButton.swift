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
    
    private var profile: Profile
    private var label: FirebaseSignInWithAppleButtonLabel
    private var onCompletion: ((Result<Profile, Error>) -> Void)
    
    @EnvironmentObject private var authenticator: FirebaseAuthenticator<Profile>
    
    public init(label: FirebaseSignInWithAppleButtonLabel, profile: Profile, onCompletion: @escaping ((Result<Profile, Error>) -> Void) = {_ in}) {
        self.label = label
        self.profile = profile
        self.onCompletion = onCompletion
    }
    
    public var body: some View {
        Button {
            continueWitApple()
        } label: {
            switch label {
            case .signIn:
                Label("Sign in with Apple", systemImage: "applelogo")
            case .signUp:
                Label("Sign up with Apple", systemImage: "applelogo")
            case .continueWithApple:
                Label("Continue with Apple", systemImage: "applelogo")
            case .custom(let text):
                Label(text, systemImage: "applelogo")
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .bold()
        .foregroundColor(.white)
        .background {
            Color.black
        }
        .cornerRadius(6)
    }
    
    func continueWitApple() {
        Task {
            do {
                try await authenticator.continueWithApple(profile: profile)
                onCompletion(.success(self.profile))
            } catch {
                onCompletion(.failure(error))
            }
        }
    }
    
}
