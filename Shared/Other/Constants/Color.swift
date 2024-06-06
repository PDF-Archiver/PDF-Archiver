//
//  UIColor.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 24.03.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

public extension Color {
    static var paDelete = Color("paDeleteAsset")
    static var paDarkGray = Color("paDarkGrayAsset")
    static var paLightGray = Color("paLightGrayAsset")
    static var paWhite = Color("paWhiteAsset")
    static var paDarkRed = Color("paDarkRedAsset")
    static var paLightRed = Color("paLightRedAsset")

    static var paPDFBackground = Color("PDFBackground")
    static var paBackground = Color("paBackgroundAsset")
    #if os(macOS)
    // swiftlint:disable:next force_unwrapping
    static var paSecondaryBackground = Color(NSColor.alternatingContentBackgroundColors.last!)
    #else
    static var paSecondaryBackground = Color("SecondaryBackground")
    #endif
    static var paKeyboardBackground = Color("KeyboardBackground")
    static var paPlaceholderGray = Color("PlaceholderGray")
}

#if os(macOS)
public extension Color {
    static var secondarySystemBackground = Color(.controlBackgroundColor)
    static var systemGray6 = Color(.darkGray)
}
#endif
