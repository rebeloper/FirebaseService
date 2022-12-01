//
//  FirestoreSort.swift
//  
//
//  Created by Alex Nagy on 01.12.2022.
//

import Foundation
import FirebaseFirestore

public struct FirestoreSort<U: Codable & Firestorable & Equatable, C: Comparable> {
    public let orderBy: String
    public let descending: Bool
    public let sortedBy: ((U, U) throws -> Bool)
    
    public init(orderBy: String,
                type: C.Type,
                descending: Bool) {
        self.orderBy = orderBy
        self.descending = descending
        if type == Timestamp.self || type == Date.self {
            self.sortedBy = { comparable0, comparable1 in
                guard let predicateSeconds0 = (comparable0.dictionary?[orderBy] as? [String: Int])?["seconds"],
                      let predicateSeconds1 = (comparable1.dictionary?[orderBy] as? [String: Int])?["seconds"],
                      let predicateNanoseconds0 = (comparable0.dictionary?[orderBy] as? [String: Int])?["nanoseconds"],
                      let predicateNanoseconds1 = (comparable1.dictionary?[orderBy] as? [String: Int])?["nanoseconds"]
                else { return false }
                
                if predicateSeconds0 == predicateSeconds1 {
                    if descending {
                        return predicateNanoseconds0 > predicateNanoseconds1
                    } else {
                        return predicateNanoseconds0 < predicateNanoseconds1
                    }
                } else {
                    if descending {
                        return predicateSeconds0 > predicateSeconds1
                    } else {
                        return predicateSeconds0 < predicateSeconds1
                    }
                }
            }
        } else {
            self.sortedBy = { comparable0, comparable1 in
                guard let predicate0 = comparable0.dictionary?[orderBy] as? C,
                      let predicate1 = comparable1.dictionary?[orderBy] as? C
                else { return false }
                
                if descending {
                    return predicate0 > predicate1
                } else {
                    return predicate0 < predicate1
                }
            }
        }
    }
    
}

