//
//  Color.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 16.07.25.
//

import SwiftUI

public extension Color {
    static var paRedAsset: Color {
        Color(.paRed)
    }

    static var paPlaceholderGrayAsset: Color {
        Color(.paPlaceholderGray)
    }

    static var paPDFBackgroundAsset: Color {
        Color(.paPDFBackground)
    }

    static var paBackgroundAsset: Color {
        Color(.paBackground)
    }

    static var paDarkGrayAsset: Color {
        Color(.paDarkGray)
    }

    static var paLightGrayAsset: Color {
        Color(.paLightGray)
    }

    static var paWhiteAsset: Color {
        Color(.paWhite)
    }

    static var secondaryLabelAsset: Color {
        #if os(macOS)
        Color(.secondaryLabelColor)
        #else
        Color(.secondaryLabel)
        #endif
    }

    static var tertiaryLabelAsset: Color {
        #if os(macOS)
        Color(.tertiaryLabelColor)
        #else
        Color(.tertiaryLabel)
        #endif
    }
}
