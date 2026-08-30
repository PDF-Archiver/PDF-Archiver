//
//  ArchiveStyleTests.swift
//  ContentExtractorEvaluations
//

import EvaluationCorpus
import Testing

@Suite("ArchiveStyle")
struct ArchiveStyleTests {

    @Test("A model description becomes the specification the filename would carry")
    func specificationFromDescription() {
        #expect(ArchiveStyle.specification(fromDescription: "Stromabrechnung E.ON") == "stromabrechnung-e-on")
        #expect(ArchiveStyle.specification(fromDescription: "Jahresübersicht Ärztekammer") == "jahresuebersicht-aerztekammer")
    }

    @Test("Descriptions about the text itself are flagged", arguments: [
        "Unlesbarer Dokumententext",
        "Dokumententext nicht lesbar",
        "no content available",
        "garbled text"
    ])
    func metaCommentaryIsDetected(description: String) {
        #expect(ArchiveStyle.containsMetaCommentary(description))
    }

    @Test("A real description is not flagged", arguments: [
        "Stromabrechnung E.ON",
        "Kontoauszug Sparkasse",
        "Gehaltsabrechnung März"
    ])
    func realDescriptionIsNotFlagged(description: String) {
        #expect(!ArchiveStyle.containsMetaCommentary(description))
    }
}
