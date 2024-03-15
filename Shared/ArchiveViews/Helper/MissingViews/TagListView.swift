//
//  TagListView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 02.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct TagListView: View {

    @Binding var tags: [String]
    let isEditable: Bool
    let isMultiLine: Bool
    let tapHandler: ((String) -> Void)?

    @ViewBuilder
    var body: some View {
        if isMultiLine {
            WrappingHStack(items: tags) { tag in
                TagView(tagName: tag, isEditable: self.isEditable, tapHandler: self.tapHandler)
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
                        tapHandler: self.tapHandler)
            }
        }
    }
}

struct TagListView_Previews: PreviewProvider {
//    @State static var tags = [
//        "billbillbillbill",
//        "ikeaikeaikea",
//        "extraLongElement",
//        "bill",
//        "ikea",
//        "flight",
//        "vacation",
//        "swift",
//        "xcode",
//        "billbillbillbill",
//        "ikeaikeaikea",
//        "extraLongElement"
//    ]
    @State static var tags = (0..<5).map { "tag\($0)" }
    static var previews: some View {
        Group {
            // Example: Document View
            TagListView(tags: $tags, isEditable: true, isMultiLine: false, tapHandler: nil)
                .previewLayout(.fixed(width: 350, height: 50))

            TagListView(tags: $tags, isEditable: true, isMultiLine: true, tapHandler: nil)
                .previewLayout(.fixed(width: 250, height: 400))

            TagListView(tags: $tags, isEditable: true, isMultiLine: true, tapHandler: nil)
                .previewLayout(.fixed(width: 400, height: 250))
        }
    }
}

extension String: Identifiable {
    public var id: String { self }
}
