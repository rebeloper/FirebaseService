//
//  Int+.swift
//  
//
//  Created by Alex Nagy on 25.05.2021.
//

import Foundation

public extension Int {
    func MB() -> Int64 {
        Int64(self * 1024 * 1024)
    }
}
