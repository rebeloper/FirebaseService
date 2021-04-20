//
//  AuthService.swift
//  
//
//  Created by Alex Nagy on 20.04.2021.
//

//
//  AuthService.swift
//  MVVMCS
//
//  Created by Alex Nagy on 23.01.2021.
//

import SwiftUI
import Firebase

public class AuthService: ObservableObject {
    
    private var authenticationStateHandler: AuthStateDidChangeListenerHandle?
    private var shouldLogoutUponLaunch: Bool
    
    @Published var isAuthViewPresented: Bool = false
    
    public init(shouldLogoutUponLaunch: Bool = false) {
        self.shouldLogoutUponLaunch = shouldLogoutUponLaunch
        addListener()
    }
    
    private func addListener() {
        if let handle = authenticationStateHandler {
            print("AuthService: removing listener...")
            Auth.auth().removeStateDidChangeListener(handle)
        }
        print("AuthService: adding listener...")
        authenticationStateHandler = Auth.auth()
            .addStateDidChangeListener { (_, user) in
                print("AuthService: did add listener with user: \(String(describing: user?.uid))")
                self.isAuthViewPresented = user == nil
            }
        
        if shouldLogoutUponLaunch {
            print("AuthService: logging out upon launch...")
            AuthService.logout()
        }
    }
    
    public static func currentUserUid() -> String? {
        Auth.auth().currentUser?.uid
    }
    
    public static func login(withEmail email: String, password: String, completion: @escaping (Result<AuthDataResult?, Error>) -> Void = {_ in}) {
        signIn(withEmail: email, password: password) { (result) in
            switch result {
            case .success(let authDataResult):
                completion(.success(authDataResult))
            case .failure(let err):
                if err._code == AuthErrorCode.userNotFound.rawValue {
                    self.signUp(withEmail: email, password: password, completion: completion)
                } else {
                    completion(.failure(err))
                }
            }
        }
    }
    
    public static func signUp(withEmail email: String, password: String, completion: @escaping (Result<AuthDataResult?, Error>) -> Void = {_ in}) {
        if Auth.auth().currentUser == nil {
            Auth.auth().createUser(withEmail: email, password: password) { (authDataResult, error) in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                completion(.success(authDataResult))
            }
        }
    }
    
    public static func signIn(withEmail email: String, password: String, completion: @escaping (Result<AuthDataResult?, Error>) -> Void = {_ in}) {
        if Auth.auth().currentUser == nil {
            Auth.auth().signIn(withEmail: email, password: password) { (authDataResult, error) in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                completion(.success(authDataResult))
            }
        }
    }
    
    public static func logout(completion: @escaping (Result<Bool, Error>) -> Void = {_ in}) {
        do {
            try Auth.auth().signOut()
            completion(.success(true))
        } catch {
            completion(.failure(error))
        }
    }
    
    public static func sendResetPassword(toEmail email: String, completion: @escaping (Result<Bool, Error>) -> Void = {_ in}) {
        Auth.auth().sendPasswordReset(withEmail: email) { (error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            completion(.success(true))
        }
    }
    
}

