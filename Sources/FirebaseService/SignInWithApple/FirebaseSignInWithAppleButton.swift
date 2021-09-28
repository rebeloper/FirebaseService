//
//  FirebaseSignInWithAppleButton.swift
//  
//
//  Created by Alex Nagy on 20.04.2021.
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import FirebaseAuth

public struct FirebaseSignInWithAppleButton: View {
    
    public var label: SignInWithAppleButton.Label
    public var requestedScopes: [ASAuthorization.Scope]?
    public var onCompletion: ((Result<FirebaseSignInWithAppleResult, Error>) -> Void)
    
    @State public var currentNonce: String? = nil
    
    public init(label: SignInWithAppleButton.Label = .signIn, requestedScopes: [ASAuthorization.Scope]? = [.fullName, .email], onCompletion: @escaping ((Result<FirebaseSignInWithAppleResult, Error>) -> Void) = {_ in}) {
        self.label = label
        self.requestedScopes = requestedScopes
        self.onCompletion = onCompletion
    }
    
    public var body: some View {
        SignInWithAppleButton(label) { (request) in
            request.requestedScopes = requestedScopes
            let nonce = randomNonceString()
            currentNonce = nonce
            request.nonce = sha256(nonce)
        } onCompletion: { (result) in
            switch result {
            case .success(let authorization):
                createToken(from: authorization)
            case .failure(let err):
                onCompletion(.failure(err))
            }
        }
    }
    
    public func createToken(from authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                onCompletion(.failure(FirebaseSignInWithAppleError.noIdentityToken))
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                onCompletion(.failure(FirebaseSignInWithAppleError.noTokenString))
                return
            }
            
            let token = FirebaseSignInWithAppleToken(appleIDCredential: appleIDCredential, nonce: nonce, idTokenString: idTokenString)
            signInToFirebase(with: token)
            
        } else {
            onCompletion(.failure(FirebaseSignInWithAppleError.noAppleIdCredential))
        }
    }
    
    public func signInToFirebase(with token: FirebaseSignInWithAppleToken) {
        
        let providerID = "apple.com"
        let idTokenString = token.idTokenString
        let nonce = token.nonce
        
        let credential = OAuthProvider.credential(withProviderID: providerID,
                                                  idToken: idTokenString,
                                                  rawNonce: nonce)
        Auth.auth().signIn(with: credential) { (authDataResult, err) in
            if let err = err {
                // Error. If error.code == .MissingOrInvalidNonce, make sure
                // you're sending the SHA256-hashed nonce as a hex string with
                // your request to Apple.
                onCompletion(.failure(err))
                return
            }
            guard let authDataResult = authDataResult else {
                onCompletion(.failure(FirebaseSignInWithAppleError.noAuthDataResult))
                return
            }
            let result = FirebaseSignInWithAppleResult(token: token, uid: authDataResult.user.uid)
            onCompletion(.success(result))
        }
    }
    
    // Adapted from https://auth0.com/docs/api-auth/tutorials/nonce#generate-a-cryptographically-random-nonce
    public func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: Array<Character> =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if length == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    @available(iOS 13, *)
    public func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    public func getName(from appleIDCredential: ASAuthorizationAppleIDCredential) -> String {
        var name = ""
        let fullName = appleIDCredential.fullName
        let givenName = fullName?.givenName ?? ""
        let middleName = fullName?.middleName ?? ""
        let familyName = fullName?.familyName ?? ""
        let names = [givenName, middleName, familyName]
        let filteredNames = names.filter {$0 != ""}
        for i in 0..<filteredNames.count {
            name += filteredNames[i]
            if i != filteredNames.count - 1 {
                name += " "
            }
        }
        return name
    }
}
