//
//  SidebarLabelStyle.swift
//  
//
//  Created by Julian Kahnert on 10.09.22.
//

import SwiftUI

struct SidebarLabelStyle: LabelStyle {
    let iconColor: Color
    let titleColor: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.icon
                .foregroundColor(iconColor)
            configuration.title
                .foregroundColor(titleColor)
        }
    }
}
