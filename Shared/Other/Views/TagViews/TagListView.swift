//
//  TagListView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 02.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct TagListView: View {

    let tags: [String]
    let isEditable: Bool
    let isSuggestion: Bool
    let isMultiLine: Bool
    let tapHandler: ((String) -> Void)?

    init(tags: [String], isEditable: Bool, isSuggestion: Bool = false, isMultiLine: Bool, tapHandler: ((String) -> Void)? = nil) {
        self.tags = tags
        self.isEditable = isEditable
        self.isSuggestion = isSuggestion
        self.isMultiLine = isMultiLine
        self.tapHandler = tapHandler
    }

    @ViewBuilder
    var body: some View {
        if isMultiLine {
            WrappingHStack(items: tags) { tag in
                TagView(tagName: tag, isEditable: self.isEditable, isSuggestion: self.isSuggestion, tapHandler: self.tapHandler)
                    .fixedSize()
            }
        } else {
            singleLineView
        }
    }

    private var singleLineView: some View {
        HStack {
            ForEach(tags.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, id: \.self) { tagName in
                TagView(tagName: tagName,
                        isEditable: self.isEditable,
                        isSuggestion: self.isSuggestion,
                        tapHandler: self.tapHandler)
            }
        }
    }
}

#Preview {
    let tags = (0..<5).map { "tag\($0)" }

    // Example: Document View
    TagListView(tags: tags, isEditable: true, isSuggestion: true, isMultiLine: false, tapHandler: nil)
        .previewLayout(.fixed(width: 350, height: 50))

    TagListView(tags: tags, isEditable: true, isSuggestion: true, isMultiLine: true, tapHandler: nil)
        .previewLayout(.fixed(width: 250, height: 400))

    TagListView(tags: tags, isEditable: true, isSuggestion: true, isMultiLine: true, tapHandler: nil)
        .previewLayout(.fixed(width: 400, height: 250))
}
