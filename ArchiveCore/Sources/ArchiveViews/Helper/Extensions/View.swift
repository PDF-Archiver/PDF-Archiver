//
//  View.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 10.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

extension View {
    func resignKeyboardOnDragGesture() -> some View {
        return modifier(ResignKeyboardOnDragGesture())
    }

    @ViewBuilder
    func wrapNavigationView(when value: Bool) -> some View {
        if value {
            NavigationView {
                self
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func listRowSeparatorHidden() -> some View {
        #if os(macOS)
        if #available(macOS 13.0, *) {
            listRowSeparator(.hidden)
        } else {
            self
        }
        #else
        if #available(iOS 15.0, *) {
            listRowSeparator(.hidden)
        } else {
            self
        }
        #endif
    }
}
