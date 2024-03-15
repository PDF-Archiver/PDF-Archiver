//
//  Stack.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 22.02.20.
//  Copyright © 2020 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct Stack<Content: View>: View {

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var spacing: CGFloat
    var content: Content

    init(spacing: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            vertical
        } else {
            horizontal
        }
        #else
        horizontal
        #endif
    }

    var vertical: some View {
        VStack(alignment: .center, spacing: spacing) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var horizontal: some View {
        HStack(alignment: .center, spacing: spacing) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct Stack_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            Stack {
                Text("Text 1")
                    .padding(.all, 20)
                    .backgroundFill(.green)
                Text("Text 2")
                    .padding(.all, 20)
                    .backgroundFill(.blue)
            }
            .previewLayout(.fixed(width: 800.0, height: 200.0))
            Stack {
                Text("Text 1")
                    .padding(.all, 20)
                    .backgroundFill(.green)
                Text("Text 2")
                    .padding(.all, 20)
                    .backgroundFill(.blue)
            }
            .previewLayout(.fixed(width: 200.0, height: 800.0))
        }
    }
}
