//
//  CallableFunctionsContext.swift
//  
//
//  Created by Alex Nagy on 02.08.2022.
//

import FirebaseFunctions

public struct CallableFunctionsContext {
    
    @discardableResult
    public static func call(_ name: String, data: Any? = nil) async throws -> HTTPSCallableResult {
        return try await Functions.functions().httpsCallable(name).call(data)
    }
    
}
