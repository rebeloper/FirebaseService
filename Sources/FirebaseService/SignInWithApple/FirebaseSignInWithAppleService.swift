//
//  FirebaseSignInWithAppleService.swift
//  
//
//  Created by Alex Nagy on 28.09.2021.
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import FirebaseAuth

public class FirebaseSignInWithAppleService: NSObject, ObservableObject {
    
    @Published public var error: Error? = nil
    @Published public var result: FirebaseSignInWithAppleResult? = nil
    
    // Unhashed nonce.
    fileprivate var currentNonce: String?
    
    public func startSignInWithAppleFlow() {
        let nonce = randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    public func createToken(from authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                error = FirebaseSignInWithAppleError.noIdentityToken
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                error = FirebaseSignInWithAppleError.noTokenString
                return
            }
            
            let token = FirebaseSignInWithAppleToken(appleIDCredential: appleIDCredential, fullName: getFullName(from: appleIDCredential), nonce: nonce, idTokenString: idTokenString)
            signInToFirebase(with: token)
            
        } else {
            error = FirebaseSignInWithAppleError.noAppleIdCredential
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
                self.error = err
                return
            }
            guard let authDataResult = authDataResult else {
                self.error = FirebaseSignInWithAppleError.noAuthDataResult
                return
            }
            let result = FirebaseSignInWithAppleResult(token: token, uid: authDataResult.user.uid)
            self.result = result
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
    
    public func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    public func getFullName(from appleIDCredential: ASAuthorizationAppleIDCredential) -> String {
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

extension FirebaseSignInWithAppleService: ASAuthorizationControllerDelegate {
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        createToken(from: authorization)
    }
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        self.error = error
    }
}

extension FirebaseSignInWithAppleService : ASAuthorizationControllerPresentationContextProviding {
    
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
    
}

