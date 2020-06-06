//
//  FilledButtonStyle.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 13.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct FilledButtonStyle: ButtonStyle {
    
    var foregroundColor: Color = Color(.paWhite)
    var backgroundColor: Color = Color(.paDarkGray)
    var isInverted: Bool = false

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding(12.0)
            .frame(maxWidth: 350.0)
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
