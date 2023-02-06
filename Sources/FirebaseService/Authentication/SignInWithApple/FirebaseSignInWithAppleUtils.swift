//
//  FirebaseSignInWithAppleUtils.swift
//  
//
//  Created by Alex Nagy on 28.09.2021.
//

import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth

public struct FirebaseSignInWithAppleUtils {
    
    // Adapted from https://auth0.com/docs/api-auth/tutorials/nonce#generate-a-cryptographically-random-nonce
    static func randomNonceString(length: Int = 32) -> String {
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
    
    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    static func signInToFirebase(with token: FirebaseSignInWithAppleToken, completion: @escaping  (Result<FirebaseSignInWithAppleResult, Error>) -> ()) {
        
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
                completion(.failure(err))
                return
            }
            guard let authDataResult = authDataResult else {
                completion(.failure(FirebaseSignInWithAppleError.noAuthDataResult))
                return
            }
            let result = FirebaseSignInWithAppleResult(token: token, uid: authDataResult.user.uid)
            completion(.success(result))
        }
    }
    
    static func createToken(from authorization: ASAuthorization, currentNonce: String?, completion: @escaping  (Result<FirebaseSignInWithAppleResult, Error>) -> ()) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                completion(.failure(FirebaseSignInWithAppleError.noIdentityToken))
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                completion(.failure(FirebaseSignInWithAppleError.noTokenString))
                return
            }
            
            let token = FirebaseSignInWithAppleToken(appleIDCredential: appleIDCredential, nonce: nonce, idTokenString: idTokenString)
            signInToFirebase(with: token) { result in
                switch result {
                case .success(let firebaseSignInWithAppleResult):
                    completion(.success(firebaseSignInWithAppleResult))
                case .failure(let err):
                    completion(.failure(err))
                }
            }
            
        } else {
            completion(.failure(FirebaseSignInWithAppleError.noAppleIdCredential))
        }
    }
}
