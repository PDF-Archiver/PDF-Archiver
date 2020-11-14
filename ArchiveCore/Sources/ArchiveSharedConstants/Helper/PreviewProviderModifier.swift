//
//  PreviewProviderModifier.swift
//  
//
//  Created by Julian Kahnert on 27.10.20.
//

#if DEBUG
import SwiftUI

struct PreviewProviderModifier: ViewModifier {

    /// Whether or not a basic light mode preview is included in the group.
    var includeLightMode: Bool

    /// Whether or not a basic dark mode preview is included in the group.
    var includeDarkMode: Bool

    /// Whether or not a preview with large text is included in the group.
    var includeLargeTextMode: Bool

    func body(content: Content) -> some View {
        Group {
            if includeLightMode {
                content
                    .previewDisplayName("Light Mode")
                    .environment(\.colorScheme, .light)
                    .previewDevice("iPhone 12")
            }

            if includeDarkMode {
                content
                    .previewDisplayName("Dark Mode")
                    .environment(\.colorScheme, .dark)
                    .previewDevice("iPhone 12")
            }

            if includeLightMode {
                content
                    .previewDisplayName("Light Mode")
                    .environment(\.colorScheme, .light)
                    .previewDevice("iPad Air (4th generation)")
            }

            if includeDarkMode {
                content
                    .previewDisplayName("Dark Mode")
                    .environment(\.colorScheme, .dark)
                    .previewDevice("iPad Air (4th generation)")
            }

            if includeLargeTextMode {
                content
                    .previewDisplayName("Large Text")
                    .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
            }
        }
    }

}

extension View {

    /// Creates a group of views with various environment settings that are useful for previews.
    ///
    /// - Parameters:
    ///   - includeLightMode: Whether or not a basic light mode preview is included in the group.
    ///   - includeDarkMode: Whether or not a basic dark mode preview is included in the group.
    ///   - includeLargeTextMode: Whether or not a preview with large text is included in the group.
    public func makeForPreviewProvider(includeLightMode: Bool = true, includeDarkMode: Bool = true, includeLargeTextMode: Bool = true) -> some View {
        modifier(
            PreviewProviderModifier(
                includeLightMode: includeLightMode,
                includeDarkMode: includeDarkMode,
                includeLargeTextMode: includeLargeTextMode
            )
        )
    }

}
#endif
