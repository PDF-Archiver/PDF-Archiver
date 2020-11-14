//
//  ErrorEmittingViewModifier.swift
//  
//
//  Created by Julian Kahnert on 30.10.20.
//
// Source: https://www.swiftbysundell.com/articles/propagating-user-facing-errors-in-swift/

import SwiftUI

struct ErrorEmittingViewModifier: ViewModifier {
    @Environment(\.errorHandler) var handler

    var error: Error?
    var retryHandler: () -> Void

    func body(content: Content) -> some View {
        handler.handle(error,
            in: content,
            retryHandler: retryHandler
        )
    }
}
