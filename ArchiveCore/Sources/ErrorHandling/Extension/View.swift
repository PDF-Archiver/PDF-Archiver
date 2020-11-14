//
//  View.swift
//  
//
//  Created by Julian Kahnert on 30.10.20.
//
// Source: https://www.swiftbysundell.com/articles/propagating-user-facing-errors-in-swift/

import SwiftUI

extension View {
    func handlingErrors(using handler: ErrorHandler) -> some View {
        environment(\.errorHandler, handler)
    }

    public func emittingError(_ error: Error?, retryHandler: @escaping () -> Void = {}) -> some View {
        modifier(ErrorEmittingViewModifier(
            error: error,
            retryHandler: retryHandler
        ))
    }
}
