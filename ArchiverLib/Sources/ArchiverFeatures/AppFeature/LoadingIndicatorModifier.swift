//
//  LoadingIndicatorModifier.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 04.10.25.
//

import SwiftUI

#if os(iOS)
struct LoadingIndicatorModifier: ViewModifier {
    let isLoading: Bool
    let isTabView: Bool

    func body(content: Content) -> some View {
        if isTabView {
            // For TabView: use tabViewBottomAccessory on iOS 26+
            if #available(iOS 26, *) {
                content
                    .tabViewBottomAccessory {
                        if isLoading {
                            ProgressView()
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
        } else {
            // For NavigationStack: use toolbar on iOS < 26
            if #available(iOS 26, *) {
                content
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
        }
    }
}
#endif
