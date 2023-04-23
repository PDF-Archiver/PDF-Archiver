//
//  UIColor.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 24.03.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

public extension Color {
    static var paDelete = Color("Delete")
    static var paDarkGray = Color("DarkGray")
    static var paLightGray = Color("LightGray")
    static var paWhite = Color("White")
    static var paDarkRed = Color("DarkRed")
    static var paLightRed = Color("LightRed")

    static var paPDFBackground = Color("PDFBackground")
    static var paBackground = Color("Background")
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
//    static var systemBackground = Color(.windowBackgroundColor)
    static var secondarySystemBackground = Color(.controlBackgroundColor)
    static var systemGray6 = Color(.darkGray)
}
#endif
