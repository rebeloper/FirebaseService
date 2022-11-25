//
//  Array+.swift
//  
//
//  Created by Alex Nagy on 22.11.2022.
//

import Foundation

public extension Array where Element: Codable & Firestorable & Equatable {
    
    @discardableResult
    mutating func append(_ document: Element, collectionPath: String, sortedBy areInIncreasingOrder: ((Element, Element) throws -> Bool)? = nil) throws -> Array  {
        let newElement = try FirestoreViewContext.create(document, collectionPath: collectionPath)
        self.append(newElement)
        self = Array(self.uniqued(on: { document in
            document.uid
        }))
        if let areInIncreasingOrder {
            self = try self.sorted(by: areInIncreasingOrder)
        }
        return self
    }
    
    @discardableResult
    mutating func delete(_ document: Element, collectionPath: String) throws -> Array  {
        try FirestoreViewContext.delete(document, collectionPath: collectionPath)
        if let index = self.firstIndex(of: document) {
            self.remove(at: index)
        }
        return self
    }
    
    @discardableResult
    mutating func update(_ document: Element, with newDocument: Element, collectionPath: String) throws -> Array  {
        let newElement = try FirestoreViewContext.update(newDocument, collectionPath: collectionPath)
        if let index = self.firstIndex(of: document) {
            self[index] = newElement
        }
        return self
    }
}
