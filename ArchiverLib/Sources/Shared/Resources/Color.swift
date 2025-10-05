//
//  Color.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 16.07.25.
//

import SwiftUI

public extension Color {
    static var paRedAsset: Color {
        Color("paRed", bundle: .module)
    }

    static var paPlaceholderGrayAsset: Color {
        Color("paPlaceholderGray", bundle: .module)
    }

    static var paPDFBackgroundAsset: Color {
        Color("paPDFBackground", bundle: .module)
    }

    static var paBackgroundAsset: Color {
        Color("paBackground", bundle: .module)
    }

    static var paDarkGrayAsset: Color {
        Color("paDarkGray", bundle: .module)
    }

    static var paLightGrayAsset: Color {
        Color("paLightGray", bundle: .module)
    }

    static var paWhiteAsset: Color {
        Color("paWhite", bundle: .module)
    }

    static var paSecondaryBackgroundAsset: Color {
        Color("paSecondaryBackground", bundle: .module)
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
