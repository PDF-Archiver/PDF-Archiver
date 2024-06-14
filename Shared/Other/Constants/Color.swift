//
//  UIColor.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 24.03.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

extension Color {
    static let paDelete = Color("paDeleteAsset")
    static let paDarkGray = Color("paDarkGrayAsset")
    static let paLightGray = Color("paLightGrayAsset")
    static let paWhite = Color("paWhiteAsset")
    static let paDarkRed = Color("paDarkRedAsset")
    static let paLightRed = Color("paLightRedAsset")

    static let paPDFBackground = Color("PDFBackground")
    static let paBackground = Color("paBackgroundAsset")
    #if os(macOS)
    // swiftlint:disable:next force_unwrapping
    static let paSecondaryBackground = Color(NSColor.alternatingContentBackgroundColors.last!)
    #else
    static let paSecondaryBackground = Color("SecondaryBackground")
    #endif
    static let paKeyboardBackground = Color("KeyboardBackground")
    static let paPlaceholderGray = Color("PlaceholderGray")
}

#if os(macOS)
extension Color {
    static let secondarySystemBackground = Color(.controlBackgroundColor)
    static let systemGray6 = Color(.darkGray)
}
#endif
