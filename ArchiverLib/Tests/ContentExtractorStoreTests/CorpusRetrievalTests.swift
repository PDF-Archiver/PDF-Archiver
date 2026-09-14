//
//  CorpusRetrievalTests.swift
//  ContentExtractorStoreTests
//
//  This is the part `ContentExtractionEvaluation` depends on that a compiler on this machine
//  actually checks - see the note at the top of CorpusRetrieval.swift.
//

import ArchiverModels
import ContentExtractorStore
import Foundation
import Testing

@Suite("CorpusRetrieval")
struct CorpusRetrievalTests {

    private func doc(_ id: Document.ID, _ specification: String, _ tags: [String]) -> Document {
        Document(id: id,
                rootKey: "corpus",
                url: URL(filePath: "/corpus/\(id).pdf"),
                date: Date(timeIntervalSince1970: Double(id)),
                specification: specification,
                tags: Set(tags),
                isTagged: true,
                sizeInBytes: 10,
                downloadStatus: 1)
    }

    @Test("The strongest textual match ranks first")
    func bestMatchRanksFirst() async throws {
        let stadtwerke = doc(1, "stadtwerke-strom", ["energie"])
        let miete = doc(2, "miete", ["wohnung"])
        let finder = CorpusRetrieval.neighbourFinder(
            seededWith: [stadtwerke, miete],
            texts: [1: "Stadtwerke Musterstadt Rechnung Stromabrechnung", 2: "Mietvertrag Wohnung Musterstrasse"]
        )

        let matches = await finder.find("Stadtwerke Stromabrechnung", nil, 5)

        #expect(matches.first?.specification == "stadtwerke-strom")
    }

    @Test("The document under test excludes itself")
    func selfExclusion() async throws {
        let own = doc(1, "eigenes-dokument", [])
        let other = doc(2, "anderes-dokument", [])
        let finder = CorpusRetrieval.neighbourFinder(
            seededWith: [own, other],
            texts: [1: "gemeinsamer wortschatz", 2: "gemeinsamer wortschatz"]
        )

        let matches = await finder.find("gemeinsamer wortschatz", 1, 5)

        #expect(!matches.contains { $0.specification == "eigenes-dokument" })
        #expect(matches.contains { $0.specification == "anderes-dokument" })
    }

    @Test("A document with no seeded text is never returned as a neighbour")
    func documentsWithoutTextAreExcluded() async throws {
        let withText = doc(1, "hat-text", [])
        let withoutText = doc(2, "hat-keinen-text", [])
        let finder = CorpusRetrieval.neighbourFinder(seededWith: [withText, withoutText], texts: [1: "rechnung strom"])

        let matches = await finder.find("rechnung strom", nil, 5)

        #expect(matches.map(\.specification) == ["hat-text"])
    }

    @Test("No usable search term returns no neighbours instead of throwing")
    func noUsableTermReturnsEmpty() async throws {
        let document = doc(1, "irrelevant", [])
        let finder = CorpusRetrieval.neighbourFinder(seededWith: [document], texts: [1: "irrelevant text"])

        let matches = await finder.find("a", nil, 5)

        #expect(matches.isEmpty)
    }
}
