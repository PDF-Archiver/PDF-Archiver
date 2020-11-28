//
//  Environment.swift
//  
//
//  Created by Julian Kahnert on 30.10.20.
//
// Source: https://www.swiftbysundell.com/articles/propagating-user-facing-errors-in-swift/

import SwiftUI

public struct ErrorHandlerEnvironmentKey: EnvironmentKey {
    public static var defaultValue: ErrorHandler = AlertErrorHandler()
}

public extension EnvironmentValues {
    var errorHandler: ErrorHandler {
        get { self[ErrorHandlerEnvironmentKey.self] }
        set { self[ErrorHandlerEnvironmentKey.self] = newValue }
    }
}
