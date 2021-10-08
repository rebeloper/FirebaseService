//
//  AuthListener.swift
//  
//
//  Created by Alex Nagy on 06.05.2021.
//

import Combine
import Firebase

public struct AuthListener {
    
    public static func listen() -> PassthroughSubject<AuthListenerResult, Error> {
        let subject = PassthroughSubject<AuthListenerResult, Error>()
        
        Auth.auth().addStateDidChangeListener { (auth, user) in
            let result = AuthListenerResult(auth: auth, user: user)
            subject.send(result)
        }
        
        return subject
    }
}

public struct AuthListenerResult {
    let auth: Auth
    let user: User?
}

