//
//  File.swift
//  
//
//  Created by Julian Kahnert on 30.10.20.
//
// Source: https://www.swiftbysundell.com/articles/propagating-user-facing-errors-in-swift/

import SwiftUI

protocol ErrorHandler {
    func handle<T: View>(
        _ error: Error?,
        in view: T,
        retryHandler: @escaping () -> Void
    ) -> AnyView
}
