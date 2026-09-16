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

        // Thresholds are calibrated to a 1911-document corpus (160 samples). The
        // earlier, stricter ones came from a 26-sample corpus where a single
        // document moved a mean by 0.038; they are not comparable.

        // A sample the model never answered for is a missing measurement, not a
        // zero, so every mean below is then taken over a smaller corpus. The
        // safety guardrails refuse ~5 of 160, which no prompt of ours controls.
        #expect(result.errors.inferenceFailureCount <= 10)
        #expect(result.errors.metricsNotFound.isEmpty)

        // Describing the text instead of the document is a bug the instructions
        // already forbid, and the user sees it verbatim in the filename.
        #expect(result.aggregateValue(.mean(of: Self.evaluation.noMetaCommentary)) >= 1.0)

        // The description becomes the filename, so a verbose one is unusable
        // however accurate it is. Splitting the prompt in two raised description
        // word count from 2.1 to 12.6 and dropped this to 0.85 while tag F1 stayed
        // flat - this is the guard that caught it.
        #expect(result.aggregateValue(.mean(of: Self.evaluation.descriptionLength)) >= 0.95)

        // Not 1.0: for a document whose every suggested tag was invented, the
        // vocabulary filter leaves none, and that is the intended answer.
        #expect(result.aggregateValue(.mean(of: Self.evaluation.suggestionOffered)) >= 0.90)

        // Only tags the archive already uses may be suggested. Short of 1.0 for
        // the same reason: a document left with no tag counts as a failure here.
        #expect(result.aggregateValue(.mean(of: Self.evaluation.tagsFromArchive)) >= 0.90)

        // The tags carry the document type, so the description has to add what
        // it is about.
        #expect(result.aggregateValue(.mean(of: Self.evaluation.descriptionAvoidsTags)) >= 0.70)

        // The optimization target: how many of the tags the user picked are
        // recovered. Measured 0.5295 with the retrieval block, the "scan the text
        // for existing tags" rule and `TagExpansion`; 0.4252 with retrieval off.
        #expect(result.aggregateValue(.mean(of: Self.evaluation.tagF1)) >= 0.50)
    }
}

#endif
