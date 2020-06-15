//
//  WidthSyncedRow.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 06.06.20.
//  Copyright © 2020 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct WidthSyncedRow<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content
    @State private var childWidth: CGFloat?

    init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        HStack(spacing: spacing) {
            content.frame(width: childWidth)
        }
    }
}
