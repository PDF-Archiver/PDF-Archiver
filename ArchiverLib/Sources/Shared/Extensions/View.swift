//
//  View.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 03.07.25.
//

import SwiftUI

extension View {
    @ViewBuilder
    nonisolated public func inspector<T: Sendable, V>(item: Binding<T?>, @ViewBuilder content: (T) -> V) -> some View where V : View {
        self
            .inspector(isPresented: .init(get: {
                item.wrappedValue != nil
            }, set: { value in
                guard !value else { return }
                item.wrappedValue = nil
            })) {
                if let value = item.wrappedValue {
                    content(value)
                } else {
                    EmptyView()
                }
            }
    }
}

