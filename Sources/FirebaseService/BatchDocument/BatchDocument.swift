//
//  BatchDocument.swift
//  
//
//  Created by Alex Nagy on 01.10.2021.
//

import Foundation

public struct BatchDocument<T: Codable & Firestorable> {
    
    public let document: T
    public let path: String
    public let merge: Bool
    
    public init(document: T, path: String, merge: Bool = false) {
        self.document = document
        self.path = path
        self.merge = merge
    }
}
