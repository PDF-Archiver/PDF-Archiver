//
//  TagListView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 02.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable identifier_name

import SwiftUI

struct TagListView: View {

    @Binding var tags: [String]
    let isEditable: Bool
    let isMultiLine: Bool
    let tapHandler: ((String) -> Void)?

    @ViewBuilder
    var body: some View {
        if isMultiLine {
            multilineView
        } else {
            singleLineView
        }
    }

    private var singleLineView: some View {
        HStack {
            ForEach(tags.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, id: \.self) { tagName in
                TagView(tagName: tagName,
                        isEditable: self.isEditable,
                        tapHandler: self.tapHandler)
            }
        }
    }

    private var multilineView: some View {
        ForEach(0...tags.count / 3, id: \.self) { rowIndex in
            HStack {
                if (rowIndex * 3 + 0) < self.tags.count {
                    TagView(tagName: self.tags[rowIndex * 3 + 0], isEditable: self.isEditable, tapHandler: self.tapHandler)
                }
                if (rowIndex * 3 + 1) < self.tags.count {
                    TagView(tagName: self.tags[rowIndex * 3 + 1], isEditable: self.isEditable, tapHandler: self.tapHandler)
                }
                if (rowIndex * 3 + 2) < self.tags.count {
                    TagView(tagName: self.tags[rowIndex * 3 + 2], isEditable: self.isEditable, tapHandler: self.tapHandler)
                }
            }
        }
    }
}

struct TagListView_Previews: PreviewProvider {
    @State static var tags = ["tag1", "tag2    ", "    tag3", "   ", "tag4"]
    static var previews: some View {
        TagListView(tags: $tags, isEditable: true, isMultiLine: true, tapHandler: nil)
    }
}

extension String: Identifiable {
    public var id: String { self }
}
