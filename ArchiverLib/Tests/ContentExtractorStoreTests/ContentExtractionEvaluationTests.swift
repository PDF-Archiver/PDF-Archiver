//
//  ContentExtractionEvaluationTests.swift
//  ContentExtractorStoreTests
//

// `canImport` for the macOS 26 SDK of CI, which has no Evaluations module at
// all; `@available` for this package's macOS 15 floor - on each declaration and
// never on the `@Suite`, which the macro rejects (swift-testing#608).
#if os(macOS) && canImport(Evaluations)

import EvaluationCorpus
import Evaluations
import Testing

@Suite("Content extraction")
struct ContentExtractionEvaluationTests {

    private static let dataset = EvaluationDataset(corpus: EvaluationCorpusFile.load())

    @available(macOS 27, *)
    private static let evaluation = ContentExtractionEvaluation(dataset: dataset)

    @available(macOS 27, *)
    @Test("Description and tag suggestions",
          .enabled(if: EvaluationCorpusFile.canRun),
          .evaluates(evaluation, info: EvaluationCorpusFile.evaluationInfo(for: dataset)))
    func suggestions() {
        let result = EvaluationContext.current.result

        // The `.xcevalresult` only opens in Xcode; this puts the same aggregates
        // in reach of a command-line run.
        Attachment.record(result.groupedSummary, named: "aggregates.txt")

        // A sample the model never answered for is a missing measurement, not a
        // zero, so every mean below is then taken over a smaller corpus. One is
        // tolerated: the safety guardrails refuse a parental-allowance notice in
        // this corpus, which no prompt of ours controls.
        #expect(result.errors.inferenceFailureCount <= 1)
        #expect(result.errors.metricsNotFound.isEmpty)

        // Describing the text instead of the document is a bug the instructions
        // already forbid, and the user sees it verbatim in the filename.
        #expect(result.aggregateValue(.mean(of: Self.evaluation.noMetaCommentary)) >= 1.0)

        // No longer 1.0: for a document whose every suggested tag was invented,
        // the vocabulary filter leaves none, and that is the intended answer.
        #expect(result.aggregateValue(.mean(of: Self.evaluation.suggestionOffered)) >= 0.96)

        // Only tags the archive already uses may be suggested. Short of 1.0 for
        // the same reason: a document left with no tag counts as a failure here.
        #expect(result.aggregateValue(.mean(of: Self.evaluation.tagsFromArchive)) >= 0.96)

        // The tags carry the document type, so the description has to add what
        // it is about. Prompt-enforced and by far the noisiest measurement here:
        // two runs of the identical prompt gave 0.76 and 0.65.
        #expect(result.aggregateValue(.mean(of: Self.evaluation.descriptionAvoidsTags)) >= 0.60)

        // The optimization target: how many of the tags the user picked are
        // recovered. Deterministic given one prompt, but the safety guardrails
        // refuse a sample on some runs, and 25 vs 26 samples moves the mean -
        // hence a small margin under the measured 0.3803.
        //
        // Down from 0.4173 for the two rules above. Precision rose 0.42 -> 0.54
        // in exchange: fewer tags, but more of them right, and none invented.
        #expect(result.aggregateValue(.mean(of: Self.evaluation.tagF1)) >= 0.40)
    }
}

#endif
