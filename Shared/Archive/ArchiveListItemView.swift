//
//  ArchiveListItemView.swift
//  iOS
//
//  Created by Julian Kahnert on 19.03.24.
//

import SwiftUI
import OSLog

struct ArchiveListItemView: View {
    let documentSpecification: String
    let documentDate: Date
    let documentTags: [String]

    init(documentSpecification: String, documentDate: Date, documentTags: [String]) {
        self.documentSpecification = documentSpecification
        self.documentDate = documentDate
        self.documentTags = documentTags
    }

    init(document: Document) {
        self.documentSpecification = document.specification
        self.documentDate = document.date
        self.documentTags = document.tags
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(documentSpecification)
                .font(.headline)
            
            Text(documentDate, format: .dateTime.year().month().day())
                .font(.subheadline)
                .foregroundStyle(.gray)
            
            // we use a list with an "empty" item to get the same hight as expected with tags
            TagListView(tags: documentTags.isEmpty ? ["empty"] : documentTags.sorted(), isEditable: false, isMultiLine: false, tapHandler: nil)
                .font(.caption)
                .opacity(documentTags.isEmpty ? 0 : 1)
        }
    }
}

#Preview("With Tags") {
    ArchiveListItemView(documentSpecification: "test-document",
                        documentDate: Date(),
                        documentTags: ["tag1", "tag2"])
}

#Preview("No Tags") {
    ArchiveListItemView(documentSpecification: "test-document",
                        documentDate: Date(),
                        documentTags: [])
}
