//
//  FirebaseSignInWithAppleError.swift
//  
//
//  Created by Alex Nagy on 20.04.2021.
//

import Foundation

public enum FirebaseSignInWithAppleError: Error {
    case noIdentityToken
    case noTokenString
    case noAppleIdCredential
    case noAuthDataResult
}
