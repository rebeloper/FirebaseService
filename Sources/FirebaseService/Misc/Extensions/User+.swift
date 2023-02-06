//
//  User+.swift
//  
//
//  Created by Alex Nagy on 06.04.2022.
//

import FirebaseAuth

extension User {
    @discardableResult
    func link(with credential: AuthCredential) async throws -> AuthDataResult {
        return try await withCheckedThrowingContinuation({ continuation in
            self.link(with: credential, completion: { authDataResut, err in
                if let err = err {
                    continuation.resume(throwing: err)
                }
                guard let authDataResut = authDataResut else {
                    continuation.resume(throwing: NSError(domain: "AuthDataResult is nil", code: 0))
                    return
                }
                continuation.resume(returning: authDataResut)
            })
        })
    }
}
