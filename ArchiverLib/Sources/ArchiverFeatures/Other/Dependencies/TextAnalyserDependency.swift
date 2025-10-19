//
//  TextAnalyserDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.25.
//

import ArchiverModels
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
    nonisolated(unsafe) static let previewValue: Self = MainActor.assumeIsolated { Self(
        getTextFrom: { _ in nil },
        parseDateFrom: { _ in [] },
        parseTagsFrom: { _ in [] },
        getFileTagsFrom: { _ in [] }
    ) }

    nonisolated(unsafe) static let testValue: Self = MainActor.assumeIsolated { Self() }
}

extension TextAnalyserDependency: DependencyKey {
    nonisolated(unsafe) static let liveValue: Self = MainActor.assumeIsolated { TextAnalyserDependency(
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
            return await DateParser.parse(text)
        },
        parseTagsFrom: { text in
            await TagParser.parse(text)
        },
        getFileTagsFrom: { url in
            try await url.getFileTags()
        }
    ) }
}

extension DependencyValues {
    nonisolated var textAnalyser: TextAnalyserDependency {
        get { self[TextAnalyserDependency.self] }
        set { self[TextAnalyserDependency.self] = newValue }
    }
}
