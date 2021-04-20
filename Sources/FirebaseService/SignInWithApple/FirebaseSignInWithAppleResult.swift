//
//  FirebaseSignInWithAppleResult.swift
//  
//
//  Created by Alex Nagy on 20.04.2021.
//

import Foundation
import FirebaseAuth

public struct FirebaseSignInWithAppleResult {
    public let token: FirebaseSignInWithAppleToken
    public let authDataResult: AuthDataResult
}
