//
//  EvaluationDatasetTests.swift
//  ContentExtractorEvaluations
//

import ArchiverModels
import EvaluationCorpus
import Foundation
import Testing

@Suite("EvaluationDataset")
struct EvaluationDatasetTests {

    private static func corpus(count: Int, specificationWords: Int = 2) -> [CorpusDocument] {
        (0..<count).map { index in
            let specification = (0..<specificationWords).map { "wort\($0)" }.joined(separator: "-")
            return CorpusDocument(filename: String(format: "2024-01-%02d--%@__tag%d.pdf", index % 28 + 1, specification, index % 5),
                                  date: Date(timeIntervalSince1970: Double(index) * 86_400),
                                  specification: specification,
                                  tags: ["tag\(index % 5)"],
                                  text: "text \(index)")
        }
    }

    @Test("Every n-th document becomes a sample, the rest becomes context")
    func splitSizes() {
        let dataset = EvaluationDataset(corpus: Self.corpus(count: 100), stride: 10)
        #expect(dataset.samples.count == 10)
        #expect(dataset.contextDocuments.count == 90)
    }

    @Test("No sample appears in the context the model gets to see")
    func samplesAreHeldOut() {
        let dataset = EvaluationDataset(corpus: Self.corpus(count: 100), stride: 10)

        let contextFilenames = Set(dataset.contextDocuments.map(\.filename))
        let sampleFilenames = Set(dataset.samples.map(\.filename))
        #expect(contextFilenames.isDisjoint(with: sampleFilenames))
    }

    @Test("The split does not depend on the order the corpus was loaded in")
    func splitIsDeterministic() {
        let corpus = Self.corpus(count: 60)
        let straight = EvaluationDataset(corpus: corpus, stride: 10)
        let shuffled = EvaluationDataset(corpus: corpus.shuffled(), stride: 10)

        #expect(straight.samples.map(\.filename) == shuffled.samples.map(\.filename))
    }

    @Test("The vocabulary holds the context tags, never a sample-only tag")
    func vocabularyComesFromContext() {
        let sampleOnly = CorpusDocument(filename: "2024-01-01--erstes-dokument__einmalig.pdf",
                                        date: Date(timeIntervalSince1970: 0),
                                        specification: "erstes-dokument",
                                        tags: ["einmalig"],
                                        text: "text")
        let dataset = EvaluationDataset(corpus: [sampleOnly] + Self.corpus(count: 20), stride: 10)

        #expect(dataset.samples.contains { $0.tags == ["einmalig"] })
        #expect(!dataset.tagVocabulary.contains("einmalig"))
        #expect(dataset.tagVocabulary.contains("tag0"))
    }

    @Test("The typical description length is taken from the archive itself")
    func typicalLengthFromArchive() {
        let dataset = EvaluationDataset(corpus: Self.corpus(count: 40, specificationWords: 3), stride: 10)
        #expect(dataset.typicalSpecificationWords == 3...3)
    }

    @Test("An empty corpus produces an empty dataset instead of crashing")
    func emptyCorpus() {
        let dataset = EvaluationDataset(corpus: [], stride: 10)
        #expect(dataset.samples.isEmpty)
        #expect(dataset.contextDocuments.isEmpty)
        #expect(dataset.tagVocabulary.isEmpty)
    }

    @Test("Context documents keep the date, so the prompt can order them")
    func contextKeepsDates() {
        let dataset = EvaluationDataset(corpus: Self.corpus(count: 30), stride: 10)
        let dates = dataset.contextDocuments.map(\.date)
        #expect(Set(dates).count == dates.count)
    }

    @Test("Without an explicit stride any archive size yields about the target sample count",
          arguments: [200, 517, 2537])
    func strideAdaptsToCorpusSize(count: Int) {
        let dataset = EvaluationDataset(corpus: Self.corpus(count: count))
        #expect((20...30).contains(dataset.samples.count))
    }

    @Test("An archive smaller than the target sample count still keeps context documents")
    func smallCorpusKeepsContext() {
        let dataset = EvaluationDataset(corpus: Self.corpus(count: 30))
        #expect(!dataset.samples.isEmpty)
        #expect(!dataset.contextDocuments.isEmpty)
    }
}
