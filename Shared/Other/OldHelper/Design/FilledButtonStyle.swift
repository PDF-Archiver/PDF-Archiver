//
//  FilledButtonStyle.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 13.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

public struct FilledButtonStyle: ButtonStyle {
    public var foregroundColor: Color = .paWhite
    public var backgroundColor: Color = .paDarkGray
    public var isInverted = false

    public init(foregroundColor: Color = .paWhite, backgroundColor: Color = .paDarkGray, isInverted: Bool = false) {
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.isInverted = isInverted
    }

    public func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding(12)
            .frame(maxWidth: 350)
            .foregroundColor(isInverted ? backgroundColor : foregroundColor)
            .background(isInverted ? foregroundColor : backgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(foregroundColor, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
