//
//  BetterCodablePropertyWrappers.swift
//  
//
//  Created by Alex Nagy on 20.04.2021.
//

import Foundation
import BetterCodable
import FirebaseFirestore

// MARK: - EmptyString
public struct DefaultEmptyStringStrategy: DefaultCodableStrategy {
    public static var defaultValue: String { return "" }
}

/// Decodes String defaulting to `""` if applicable
///
/// `@DefaultEmptyString` decodes Strings and defaults the value to an empty string if the Decoder is unable to decode the value.
public typealias DefaultEmptyString = DefaultCodable<DefaultEmptyStringStrategy>

// MARK: - ZeroInt
public struct DefaultZeroIntStrategy: DefaultCodableStrategy {
    public static var defaultValue: Int { return Int.zero }
}

/// Decodes Int defaulting to `0` if applicable
///
/// `@DefaultZeroInt` decodes Ints and defaults the value to an 0 if the Decoder is unable to decode the value.
public typealias DefaultZeroInt = DefaultCodable<DefaultZeroIntStrategy>

// MARK: - ZeroDouble
public struct DefaultZeroDoubleStrategy: DefaultCodableStrategy {
    public static var defaultValue: Double { return Double.zero }
}

/// Decodes Double defaulting to `0.0` if applicable
///
/// `@DefaultZeroDouble` decodes Doubles and defaults the value to an 0.0 if the Decoder is unable to decode the value.
public typealias DefaultZeroDouble = DefaultCodable<DefaultZeroDoubleStrategy>

// MARK: - Now
public struct DefaultNowStrategy: DefaultCodableStrategy {
    public static var defaultValue: Date { return Date() }
}

/// Decodes Date defaulting to now if applicable
///
/// `@DefaultNow` decodes Dates and defaults the value to now if the Decoder is unable to decode the value.
public typealias DefaultNow = DefaultCodable<DefaultNowStrategy>

// MARK: - Timestamp
public struct DefaultTimestampStrategy: DefaultCodableStrategy {
    public static var defaultValue: Timestamp { return Timestamp() }
}

/// Decodes Timestamp defaulting to now if applicable
///
/// `@DefaultTimestamp` decodes Timestamps and defaults the value to now if the Decoder is unable to decode the value.
public typealias DefaultTimestamp = DefaultCodable<DefaultTimestampStrategy>
