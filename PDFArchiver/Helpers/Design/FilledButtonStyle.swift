//
//  FilledButtonStyle.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 13.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct FilledButtonStyle: ButtonStyle {

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding(12.0)
            .frame(maxWidth: 350.0)
            .foregroundColor(Color(.paWhite))
            .background(Color(.paDarkGray))
            .cornerRadius(8.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
