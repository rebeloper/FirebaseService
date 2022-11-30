//
//  Timestamp+.swift
//  
//
//  Created by Alex Nagy on 01.12.2022.
//

import FirebaseFirestore

extension Timestamp: Comparable {
    public static func < (lhs: Timestamp, rhs: Timestamp) -> Bool {
        if lhs.seconds != rhs.seconds {
            return lhs.seconds < rhs.seconds
        } else {
            return lhs.nanoseconds < rhs.nanoseconds
        }
    }
    
    public static func <= (lhs: Timestamp, rhs: Timestamp) -> Bool {
        if lhs.seconds != rhs.seconds {
            return lhs.seconds <= rhs.seconds
        } else {
            return lhs.nanoseconds <= rhs.nanoseconds
        }
    }

    public static func > (lhs: Timestamp, rhs: Timestamp) -> Bool {
        if lhs.seconds != rhs.seconds {
            return lhs.seconds > rhs.seconds
        } else {
            return lhs.nanoseconds > rhs.nanoseconds
        }
    }

    public static func >= (lhs: Timestamp, rhs: Timestamp) -> Bool {
        if lhs.seconds != rhs.seconds {
            return lhs.seconds >= rhs.seconds
        } else {
            return lhs.nanoseconds >= rhs.nanoseconds
        }
    }

    public static func == (lhs: Timestamp, rhs: Timestamp) -> Bool {
        return lhs.seconds == rhs.seconds && lhs.nanoseconds == rhs.nanoseconds
    }
}
