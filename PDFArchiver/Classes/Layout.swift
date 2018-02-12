//
//  ColorScheme.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 10.02.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

struct Layout {
    // basic color from: https://color.adobe.com/de/Simple-Theme-color-theme-10451401/
    let color1 = CGColor.init(red: 0.793, green: 0.255, blue: 0.310, alpha: 1)
    let color2 = CGColor.init(red: 0.903, green: 0.412, blue: 0.404, alpha: 1)
    let color3 = CGColor.init(red: 0.980, green: 0.980, blue: 0.980, alpha: 1)
    let color4 = CGColor.init(red: 0.131, green: 0.172, blue: 0.231, alpha: 1)
    let color5 = CGColor.init(red: 0.213, green: 0.242, blue: 0.286, alpha: 1)

    // other colors
    let fieldBackgroundColorDark: CGColor
    let fieldBackgroundColorLight: CGColor

    // layout stuff
    let cornerRadius = CGFloat(integerLiteral: 3)

    init() {
        self.fieldBackgroundColorDark = color5.copy(alpha: 0.7)!
        self.fieldBackgroundColorLight = color4.copy(alpha: 0.3)!
    }
}
