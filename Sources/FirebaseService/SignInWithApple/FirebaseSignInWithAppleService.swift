//
//  FirebaseSignInWithAppleService.swift
//  
//
//  Created by Alex Nagy on 28.09.2021.
//

import SwiftUI
import AuthenticationServices
import FirebaseAuth

public class FirebaseSignInWithAppleService: NSObject, ObservableObject {
    
    private var onCompleted: ((FirebaseSignInWithAppleResult) -> ())? = nil
    private var onFailed: ((Error) -> ())? = nil
    
    // Unhashed nonce.
    fileprivate var currentNonce: String?
    
    public func signIn(onCompleted: @escaping (FirebaseSignInWithAppleResult) -> (), onFailed: @escaping (Error) -> ()) {
        self.onCompleted = onCompleted
        self.onFailed = onFailed
        
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
    
}

extension FirebaseSignInWithAppleService: ASAuthorizationControllerDelegate {
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        FirebaseSignInWithAppleUtils.createToken(from: authorization, currentNonce: currentNonce) { result in
            switch result {
            case .success(let firebaseSignInWithAppleResult):
                self.onCompleted?(firebaseSignInWithAppleResult)
            case .failure(let err):
                self.onFailed?(err)
            }
        }
    }
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onFailed?(error)
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

