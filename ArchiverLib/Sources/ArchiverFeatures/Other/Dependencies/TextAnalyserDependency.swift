//
//  TextAnalyserDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.25.
//

import ArchiverDatabase
import ArchiverModels
import ComposableArchitecture
import PDFKit
import Shared
import SQLiteData

@DependencyClient
struct TextAnalyserDependency {
    var getTextFrom: @Sendable (Document) async -> String?
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
        getTextFrom: { document in
            @Dependency(\.defaultDatabase) var database

            let indexed = await withErrorReporting {
                try await database.read { db in
                    try DocumentText.prefix(of: document.id).fetchOne(db)
                }
            }
            .flatMap(\.self)
            if let indexed, !indexed.isEmpty {
                return indexed
            }

            // Nothing indexed yet - a fresh scan, or an archive without Premium.
            guard let pdfDocument = PDFDocument(url: document.url) else { return nil }
            var text = ""
            for index in 0 ..< min(pdfDocument.pageCount, 3) {
                guard text.count < Document.analysedTextLength,
                      let page = pdfDocument.page(at: index),
                      let pageContent = page.string else { continue }

                text += pageContent
            }

            return text.isEmpty ? nil : String(text.prefix(Document.analysedTextLength))
        },
        parseDateFrom: { text in
            return await DateParser.parse(text)
        },
        parseTagsFrom: { text in
            await TagParser.parse(text)
        },
        getFileTagsFrom: { url in
            try await url.getFileTags()
        }
    )
}

extension DependencyValues {
    var textAnalyser: TextAnalyserDependency {
        get { self[TextAnalyserDependency.self] }
        set { self[TextAnalyserDependency.self] = newValue }
    }
}
