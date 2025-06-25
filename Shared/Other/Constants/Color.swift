//
//  UIColor.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 24.03.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

#warning("TODO: move this to library")
extension Color {
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
    #endif
    static let paPlaceholderGray = Color("PlaceholderGray")
}
