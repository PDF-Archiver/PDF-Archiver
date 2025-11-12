//
//  Color.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 16.07.25.
//

import SwiftUI

public extension Color {
    static var paRedAsset: Color {
        Color("paRed", bundle: #bundle)
    }

    static var paPlaceholderGrayAsset: Color {
        Color("paPlaceholderGray", bundle: #bundle)
    }

    static var paPDFBackgroundAsset: Color {
        Color("paPDFBackground", bundle: #bundle)
    }

    static var paBackgroundAsset: Color {
        Color("paBackground", bundle: #bundle)
    }

    static var paDarkGrayAsset: Color {
        Color("paDarkGray", bundle: #bundle)
    }

    static var paLightGrayAsset: Color {
        Color("paLightGray", bundle: #bundle)
    }

    static var paWhiteAsset: Color {
        Color("paWhite", bundle: #bundle)
    }

    static var paSecondaryBackgroundAsset: Color {
        Color("paSecondaryBackground", bundle: #bundle)
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
