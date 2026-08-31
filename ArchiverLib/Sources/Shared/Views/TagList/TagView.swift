//
//  TagView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 10.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

public struct TagView: View {

    let tagName: String
    let isEditable: Bool
    let isSuggestion: Bool
    let tapHandler: ((String) -> Void)?

    public init(tagName: String, isEditable: Bool, isSuggestion: Bool, tapHandler: ((String) -> Void)?) {
        self.tagName = tagName
        self.isEditable = isEditable
        self.isSuggestion = isSuggestion
        self.tapHandler = tapHandler
    }

    public var body: some View {
        if let tapHandler {
            Button {
                tapHandler(tagName)
            } label: {
                tag
            }
            .buttonStyle(BorderlessButtonStyle())
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(actionHint)
        } else {
            self.tag
                .accessibilityLabel(accessibilityLabel)
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
                    .accessibilityHidden(true)
            }
            .fixedSize()
        } else {
            Text(tagName.capitalized)
        }
    }

    // VoiceOver never sees the fill colour, so the suggestion state has to be in the words.
    private var accessibilityLabel: Text {
        if isSuggestion {
            return Text("Suggested tag: \(tagName.capitalized)", bundle: #bundle)
        }
        return Text(tagName.capitalized)
    }

    // The chip looks identical whether a tap adds or removes the tag; only the hint says which.
    private var actionHint: Text {
        if isSuggestion {
            return Text("Adds this tag to the document", bundle: #bundle)
        }
        return Text("Removes this tag from the document", bundle: #bundle)
    }

    private var tag: some View {
        buttonLabel
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .padding(EdgeInsets(top: 2.0, leading: 5.0, bottom: 2.0, trailing: 5.0))
            .foregroundColor(.white)
            .background(isSuggestion ? Color.gray : Color.paRedAsset)
            .cornerRadius(8.0)
            .overlay(suggestionMarker)
            .transition(.opacity)
//            .animation(.spring())
            .id(tagName)
    }

    // Colour alone must not carry the suggestion state (WCAG 1.4.1).
    @ViewBuilder
    private var suggestionMarker: some View {
        if isSuggestion {
            RoundedRectangle(cornerRadius: 8.0)
                .strokeBorder(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
        }
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
