//
//  UIColor.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 24.03.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

public extension Color {

    static var paDelete: Color { return Color("Delete") }
    static var paDarkGray: Color { return Color("DarkGray") }
    static var paLightGray: Color { return Color("LightGray") }
    static var paWhite: Color { return Color("White") }
    static var paDarkRed: Color { return Color("DarkRed") }
    static var paLightRed: Color { return Color("LightRed") }

    static var paPDFBackground: Color { return Color("PDFBackground") }
    static var paBackground: Color { return Color("Background") }
    static var paSecondaryBackground: Color { return Color("SecondaryBackground") }
    static var paKeyboardBackground: Color { return Color("KeyboardBackground") }
    static var paPlaceholderGray: Color { return Color("PlaceholderGray") }
}

#if os(macOS)
public extension Color {
    static var systemBackground: Color { return Color(.windowBackgroundColor) }
    static var secondarySystemBackground: Color { return Color(.controlBackgroundColor) }
    static var systemGray6: Color { return Color(.darkGray) }
}
#endif
