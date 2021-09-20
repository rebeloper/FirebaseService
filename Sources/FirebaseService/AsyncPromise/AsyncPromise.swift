//
//  AsyncPromise.swift
//  
//
//  Created by Alex Nagy on 20.09.2021.
//

import Combine

public struct AsyncPromise<T: Codable & Firestorable> {
    @available(iOS 15.0, *)
    public static func fulfil(_ promise: Future<T, Error>, storedIn cancellables: inout Set<AnyCancellable>) async throws -> T {
        try await withCheckedThrowingContinuation({ continuation in
            promise.sink { result in
                switch result {
                case .finished:
                    break
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            } receiveValue: { value in
                continuation.resume(returning: value)
            }
            .store(in: &cancellables)
        })
    }
}
