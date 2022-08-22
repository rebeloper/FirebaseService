//
//  PassthroughPromise.swift
//  
//
//  Created by Alex Nagy on 22.08.2022.
//

import Foundation
import Combine

public struct PassthroughPromise<T> {
    
    public static func fulfill(_ promise: PassthroughSubject<T, Error>, storedIn cancellables: inout Set<AnyCancellable>, completion: @escaping (Result<T, Error>) -> ()) {
        promise.sink { result in
            switch result {
            case .finished:
                break
            case .failure(let err):
                DispatchQueue.main.async {
                    completion(.failure(err))
                }
            }
        } receiveValue: { value in
            DispatchQueue.main.async {
                completion(.success(value))
            }
        }
        .store(in: &cancellables)
    }
}

