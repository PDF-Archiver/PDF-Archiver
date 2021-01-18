//
//  VerticalLabelStyle.swift
//  
//
//  Created by Julian Kahnert on 18.01.21.
//

import SwiftUI

struct VerticalLabelStyle: LabelStyle {
    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            configuration.icon
            configuration.title
                .font(.caption)
        }
    }
}
