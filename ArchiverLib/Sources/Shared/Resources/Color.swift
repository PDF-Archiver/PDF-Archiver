//
//  Color.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 16.07.25.
//

import SwiftUI

public extension Color {
    static var paDarkRedAsset: Color {
        Color(.paDarkRed)
    }

    static var paLightRedAsset: Color {
        Color(.paLightRed)
    }

    static var paPlaceholderGrayAsset: Color {
        Color(.paPlaceholderGray)
    }

    static var secondaryLabelAsset: Color {
        #if os(macOS)
        Color(.secondaryLabelColor)
        #else
        Color(.secondaryLabel)
        #endif
    }
}
