//
//  SubscriptionButtonStyle.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 06.06.20.
//  Copyright © 2020 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct SubscriptionButtonStyle: ButtonStyle {

    private let foregroundColor: Color = .paBackground
    private let backgroundColor: Color = .paDarkGray
    var isPreferred = false

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding(8)
            .frame(maxWidth: 300)
            .foregroundColor(isPreferred ? foregroundColor : backgroundColor)
            .background(isPreferred ? backgroundColor : foregroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isPreferred ? foregroundColor : backgroundColor, lineWidth: 1)
            )
            .shadow(radius: isPreferred ? 4 : 0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
