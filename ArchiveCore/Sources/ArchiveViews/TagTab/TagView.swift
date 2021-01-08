//
//  TagView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 10.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct TagView: View, Identifiable {

    var id: String {
        tagName
    }

    let tagName: String
    let isEditable: Bool
    let tapHandler: ((String) -> Void)?

    var body: some View {
        if let tapHandler = tapHandler {
            Button(action: {
                tapHandler(self.tagName)
            }, label: {
                self.tag
            })
            .buttonStyle(BorderlessButtonStyle())
        } else {
            self.tag
        }
    }

    @ViewBuilder
    private var buttonLabel: some View {
        if isEditable {
            HStack(alignment: .center) {
                Label(tagName.capitalized, systemImage: "tag")
                Spacer()
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        } else {
            Label(tagName.capitalized, systemImage: "tag")
        }
    }

    private var tag: some View {
        buttonLabel
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(EdgeInsets(top: 2.0, leading: 5.0, bottom: 2.0, trailing: 5.0))
            .fixedSize()
            .foregroundColor(.white)
            .background(.paDarkRed)
            .cornerRadius(8.0)
            .transition(.opacity)
            .animation(.spring())
    }
}

struct TagView_Previews: PreviewProvider {
    static var tapHandler: ((String) -> Void) = { tag in
        print("Tapped on tag: \(tag)")
    }

    static var previews: some View {
        Group {
            TagView(tagName: "tag1",
                    isEditable: true,
                    tapHandler: tapHandler)

            TagView(tagName: "tag2",
                    isEditable: false,
                    tapHandler: tapHandler)

            TagView(tagName: "t",
                    isEditable: false,
                    tapHandler: tapHandler)

        }
        .previewLayout(.sizeThatFits)
    }
}
