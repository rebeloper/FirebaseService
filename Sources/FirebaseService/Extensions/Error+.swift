//
//  Error+.swift
//  
//
//  Created by Alex Nagy on 25.05.2021.
//

import Foundation

extension Error {
    var message: String {
        switch self {
        case is FirebaseError:
            return (self as? FirebaseError)?.rawValue.description ?? self.localizedDescription
        default:
            return self.localizedDescription
        }
    }
}
