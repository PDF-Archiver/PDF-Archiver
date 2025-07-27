//
//  TextAnalyserDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.25.
//

import ComposableArchitecture
import PDFKit
import Shared

@DependencyClient
struct TextAnalyserDependency {
    var getTextFrom: @Sendable (URL) async -> String?
    var parseDateFrom: @Sendable (String) async -> [Date] = { _ in [] }
    var parseTagsFrom: @Sendable (String) async -> Set<String> = { _ in [] }
    var getFileTagsFrom: @Sendable (URL) async throws -> [String]
}

extension TextAnalyserDependency: TestDependencyKey {
    static let previewValue = Self(
        getTextFrom: { _ in nil },
        parseDateFrom: { _ in [] },
        parseTagsFrom: { _ in [] },
        getFileTagsFrom: { _ in [] }
    )

    static let testValue = Self()
}

extension TextAnalyserDependency: DependencyKey {
  static let liveValue = TextAnalyserDependency(
    getTextFrom: { url in
        guard let pdfDocument = PDFDocument(url: url) else { return nil }

        // get the pdf content of first 3 pages
        var text = ""
        for index in 0 ..< min(pdfDocument.pageCount, 3) {
            guard let page = pdfDocument.page(at: index),
                  let pageContent = page.string else { continue }

            text += pageContent
        }

        return text.isEmpty ? nil : text
    },
    parseDateFrom: { text in
        return DateParser.parse(text)
    },
    parseTagsFrom: { text in
        TagParser.parse(text)
    },
    getFileTagsFrom: { url in
        try url.getFileTags()
    }
  )
}

extension DependencyValues {
  var textAnalyser: TextAnalyserDependency {
    get { self[TextAnalyserDependency.self] }
    set { self[TextAnalyserDependency.self] = newValue }
  }
}
