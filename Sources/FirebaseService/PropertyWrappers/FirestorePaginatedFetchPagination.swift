//
//  FirestorePaginatedFetchPagination.swift
//  
//
//  Created by Alex Nagy on 22.11.2022.
//

import Foundation

public struct FirestorePaginatedFetchPagination {
    public let orderBy: String
    public let descending: Bool
    public let limit: Int
    public let sortedBy: ((Any, Any) throws -> Bool)?
    
    public init(orderBy: String, descending: Bool, limit: Int, sortedBy: ((Any, Any) throws -> Bool)? = nil) {
        self.orderBy = orderBy
        self.descending = descending
        self.limit = limit
        self.sortedBy = sortedBy
    }
}
