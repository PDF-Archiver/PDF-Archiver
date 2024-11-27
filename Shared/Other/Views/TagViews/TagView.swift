//
//  TagView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 10.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct TagView: View {

    let tagName: String
    let isEditable: Bool
    let isSuggestion: Bool
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
                Text(tagName.capitalized)
                Spacer()
                Image(systemName: "xmark.circle")
                    .font(.caption)
            }
        } else {
            Text(tagName.capitalized)
        }
    }

    private var tag: some View {
        buttonLabel
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(EdgeInsets(top: 2.0, leading: 5.0, bottom: 2.0, trailing: 5.0))
            .foregroundColor(.white)
            .background(isSuggestion ? Color.gray : Color.paDarkRed)
            .cornerRadius(8.0)
            .transition(.opacity)
//            .animation(.spring())
            .id(tagName)
    }
}

#Preview {
    TagView(tagName: "tag1",
            isEditable: true,
            isSuggestion: true,
            tapHandler: { _ in })

    TagView(tagName: "tag2",
            isEditable: false,
            isSuggestion: false,
            tapHandler: { _ in })

    TagView(tagName: "t",
            isEditable: false,
            isSuggestion: false,
            tapHandler: { _ in })
}
