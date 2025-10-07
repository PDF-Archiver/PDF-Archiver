//
//  LoadingIndicatorModifier.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 04.10.25.
//

import SwiftUI

struct LoadingIndicatorModifier: ViewModifier {
    let isLoading: Bool

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .toolbar {
                if isLoading {
                    ToolbarItem(placement: .status) {
                        ProgressView()
                            .frame(width: 32, height: 32)
                            .controlSize(.small)
                    }
                }
            }
        #else
        if #available(iOS 26, *) {
            content
                .tabViewBottomAccessory {
                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Loading documents")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                }
        } else {
            content
                .toolbar {
                    if isLoading {
                        ToolbarItem(placement: .destructiveAction) {
                            ProgressView()
                        }
                    }
                }
        }
        #endif
    }
}
