//
//  ArchiveListItemView.swift
//  iOS
//
//  Created by Julian Kahnert on 19.03.24.
//

import ArchiverDatabase
import OSLog
import Shared
import SwiftUI

struct ArchiveListItemView: View {
    let documentSpecification: String
    let documentDate: Date
    let documentTags: [String]
    /// FTS5 snippet of a content-only hit, with the matched terms marked. `nil` when the filename
    /// already shows why the row is here.
    let snippet: String?

    init(documentSpecification: String, documentDate: Date, documentTags: [String], snippet: String? = nil) {
        self.documentSpecification = documentSpecification
        self.documentDate = documentDate
        self.documentTags = documentTags
        self.snippet = snippet
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(documentSpecification)
                .font(.headline)

            Text(documentDate, format: .dateTime.year().month().day())
                .font(.subheadline)
                .foregroundStyle(.gray)

            if let snippet {
                Text(Self.styled(snippet))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // we use a list with an "empty" item to get the same hight as expected with tags
            TagListView(tags: documentTags.isEmpty ? ["empty"] : documentTags.sorted(), isEditable: false, isMultiLine: false, tapHandler: nil)
                .font(.caption)
                .opacity(documentTags.isEmpty ? 0 : 1)
        }
    }
}

extension ArchiveListItemView {
    /// Turns the snippet's markers into bold runs. FTS5 has no styling, only delimiters.
    static func styled(_ snippet: String) -> AttributedString {
        var result = AttributedString()
        var isMatch = false
        for part in snippet.split(separator: Document.snippetOpenMarker, omittingEmptySubsequences: false) {
            for (index, piece) in part.split(separator: Document.snippetCloseMarker, omittingEmptySubsequences: false).enumerated() {
                var run = AttributedString(piece)
                if isMatch, index == 0 {
                    run.font = .caption.bold()
                }
                result += run
            }
            isMatch = true
        }
        return result
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

#Preview("Content Hit") {
    ArchiveListItemView(documentSpecification: "test-document",
                        documentDate: Date(),
                        documentTags: ["tag1"],
                        snippet: "…Ihre \(Document.snippetOpenMarker)Rechnung\(Document.snippetCloseMarker) für Müller GmbH…")
}
