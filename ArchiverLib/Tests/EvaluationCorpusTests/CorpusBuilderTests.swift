//
//  CorpusBuilderTests.swift
//  ContentExtractorEvaluations
//

import ArchiverModels
@testable import EvaluationCorpus
import Foundation
import Testing

@Suite("CorpusBuilder ground truth")
struct CorpusBuilderTests {

    @Test("A filed document yields date, description and tags")
    func filedDocument() async throws {
        let truth = try #require(await CorpusBuilder.groundTruth(fromFilename: "2024-03-11--stromabrechnung-eon__rechnung_strom.pdf"))

        #expect(truth.specification == "stromabrechnung-eon")
        #expect(truth.tags == ["rechnung", "strom"])
        #expect(DateFormatter.yyyyMMdd.string(from: truth.date) == "2024-03-11")
    }

    @Test("Documents without a complete ground truth are rejected", arguments: [
        "2024-03-11--stromabrechnung-eon.pdf",
        "stromabrechnung-eon__rechnung.pdf",
        "2024-03-11--__rechnung.pdf",
        "scan 2024-03-11.pdf"
    ])
    func incompleteFilename(filename: String) async {
        #expect(await CorpusBuilder.groundTruth(fromFilename: filename) == nil)
    }

    @Test("Untagged imports are rejected - their placeholders are not ground truth")
    func placeholders() async {
        let untaggedDescription = "2024-03-11--\(Document.descriptionPlaceholder)1__rechnung.pdf"
        #expect(await CorpusBuilder.groundTruth(fromFilename: untaggedDescription) == nil)

        let untaggedTags = "2024-03-11--stromabrechnung-eon__\(Document.tagPlaceholder).pdf".lowercased()
        #expect(await CorpusBuilder.groundTruth(fromFilename: untaggedTags) == nil)
    }
}
