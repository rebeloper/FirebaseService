//
//  AuthService.swift
//  
//
//  Created by Alex Nagy on 20.04.2021.
//

import Firebase
import Combine

public struct AuthService {
    
    public static func currentUserUid() -> String? {
        Auth.auth().currentUser?.uid
    }
    
    public static func logout() -> Future<Bool, Error> {
        return Future<Bool, Error> { completion in
            do {
                try Auth.auth().signOut()
                completion(.success(true))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    public static func signIn(withEmail email: String, password: String) -> Future<AuthDataResult?, Error> {
        return Future<AuthDataResult?, Error> { completion in
            if Auth.auth().currentUser == nil {
                Auth.auth().signIn(withEmail: email, password: password) { (authDataResult, error) in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    completion(.success(authDataResult))
                }
            } else {
                completion(.failure(FirebaseError.alreadySignedIn))
            }
        }
    }
    
    public static func signUp(withEmail email: String, password: String) -> Future<AuthDataResult?, Error> {
        return Future<AuthDataResult?, Error> { completion in
            if Auth.auth().currentUser == nil {
                Auth.auth().createUser(withEmail: email, password: password) { (authDataResult, error) in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    completion(.success(authDataResult))
                }
            } else {
                completion(.failure(FirebaseError.alreadySignedIn))
            }
        }
    }
    
    public static func sendResetPassword(toEmail email: String) -> Future<Bool, Error> {
        return Future<Bool, Error> { completion in
            Auth.auth().sendPasswordReset(withEmail: email) { (error) in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                completion(.success(true))
            }
        }
    }
    
}
