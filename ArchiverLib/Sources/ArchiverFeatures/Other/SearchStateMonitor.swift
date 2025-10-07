//
//  SearchStateMonitor.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.10.25.
//

import SwiftUI

/// Monitors the search state from the SwiftUI environment.
///
/// This modifier is necessary because `isSearching` must be read from a subview
/// of the searchable modifier, not from the same view that applies `.searchable()`.
/// As documented by Apple: "Read this value from within the content of a searchable
/// view, not from the same view or one of its ancestors."
///
/// See: https://developer.apple.com/documentation/swiftui/environmentvalues/issearching/
struct SearchStateMonitor: ViewModifier {
    @Environment(\.isSearching) var isSearching
    let onSearchStateChanged: (Bool, Bool) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: isSearching) { oldValue, newValue in
                onSearchStateChanged(oldValue, newValue)
            }
    }
}
