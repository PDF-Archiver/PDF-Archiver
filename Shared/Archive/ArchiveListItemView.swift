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
    let documentSize: Measurement<UnitInformationStorage>

    init(documentSpecification: String, documentDate: Date, documentTags: [String], documentSize: Measurement<UnitInformationStorage>) {
        self.documentSpecification = documentSpecification
        self.documentDate = documentDate
        self.documentTags = documentTags
        self.documentSize = documentSize
    }

    init(document: Document) {
        self.documentSpecification = document.specification
        self.documentDate = document.date
        self.documentTags = document.tags
        self.documentSize = document.size
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(documentSpecification)
                        .font(.headline)
                    Text(documentDate, format: .dateTime.year().month().day())
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
                Spacer()
            }

            TagListView(tags: documentTags.sorted(), isEditable: false, isMultiLine: false, tapHandler: nil)
                .font(.caption)
        }
    }
}

#Preview {
    ArchiveListItemView(documentSpecification: "test-document",
                        documentDate: Date(),
                        documentTags: ["tag1", "tag2"],
                        documentSize: .init(value: 12345, unit: .kilobytes))
}
