//
//  Animated.swift
//  
//
//  Created by Alex Nagy on 22.11.2022.
//

import SwiftUI

@discardableResult
public func animated<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(animation, body)
}
