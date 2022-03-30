//
//  AuthState.swift
//  
//
//  Created by Alex Nagy on 06.05.2021.
//

import Combine
import Firebase

public class AuthState: ObservableObject {
    
    @Published public var user: User? = nil
    @Published public var value: AuthenticationStateValue = .undefined
    @Published public var currentUserUid: String? = nil
    @Published public var email: String = ""
    
    public var cancellables: Set<AnyCancellable> = []
    
    public init(shouldLogoutUponLaunch: Bool = false) {
        print("AuthState init")
        startAuthListener()
        logoutIfNeeded(shouldLogoutUponLaunch)
    }
    
    private func startAuthListener() {
        let promise = AuthListener.listen()
        promise.sink { _ in } receiveValue: { result in
            self.user = result.user
            self.currentUserUid = result.user?.uid
            self.email = result.user?.email ?? ""
            self.value = result.user != nil ? .authenticated : .notAuthenticated
        }.store(in: &cancellables)
    }
    
    private func logoutIfNeeded(_ shouldLogoutUponLaunch: Bool) {
        if shouldLogoutUponLaunch {
            print("AuthState: logging out upon launch...")
            let promise = AuthService.logout()
            promise.sink { result in
                switch result {
                case .finished:
                    break
                case .failure(let err):
                    print(err.localizedDescription)
                }
            } receiveValue: { success in
                print("Logged out: \(success)")
            }.store(in: &cancellables)

        }
    }
}
