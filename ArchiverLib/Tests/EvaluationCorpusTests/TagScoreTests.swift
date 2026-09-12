//
//  TagScoreTests.swift
//  ContentExtractorEvaluations
//

import EvaluationCorpus
import Testing

@Suite("TagScore")
struct TagScoreTests {

    @Test("An exact match scores perfectly")
    func exactMatch() {
        let score = TagScore(suggested: ["rechnung", "strom"], expected: ["strom", "rechnung"])
        #expect(score.precision == 1)
        #expect(score.recall == 1)
        #expect(score.f1Score == 1)
    }

    @Test("A superfluous tag costs precision, not recall")
    func superfluousTag() {
        let score = TagScore(suggested: ["rechnung", "strom", "eon"], expected: ["rechnung", "strom"])
        #expect(score.precision == 2.0 / 3.0)
        #expect(score.recall == 1)
    }

    @Test("A missing tag costs recall, not precision")
    func missingTag() {
        let score = TagScore(suggested: ["rechnung"], expected: ["rechnung", "strom"])
        #expect(score.precision == 1)
        #expect(score.recall == 0.5)
    }

    @Test("No overlap scores zero")
    func noOverlap() {
        let score = TagScore(suggested: ["urlaub"], expected: ["rechnung"])
        #expect(score.precision == 0)
        #expect(score.recall == 0)
        #expect(score.f1Score == 0)
    }

    @Test("Suggesting nothing is a failure, not perfect precision")
    func emptySuggestion() {
        let score = TagScore(suggested: [], expected: ["rechnung"])
        #expect(score.precision == 0)
        #expect(score.recall == 0)
        #expect(score.f1Score == 0)
    }

    @Test("F1 is the harmonic mean of precision and recall")
    func harmonicMean() {
        let score = TagScore(suggested: ["rechnung", "urlaub"], expected: ["rechnung", "strom"])
        #expect(score.precision == 0.5)
        #expect(score.recall == 0.5)
        #expect(score.f1Score == 0.5)
    }
}
