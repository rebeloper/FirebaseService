//
//  FirebaseSignInWithAppleToken.swift
//  
//
//  Created by Alex Nagy on 20.04.2021.
//

import Foundation
import AuthenticationServices

public struct FirebaseSignInWithAppleToken {
    public let appleIDCredential: ASAuthorizationAppleIDCredential
    public let nonce: String
    public let idTokenString: String
}
