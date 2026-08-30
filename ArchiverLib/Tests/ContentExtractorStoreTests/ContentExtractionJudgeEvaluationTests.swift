//
//  ContentExtractionJudgeEvaluationTests.swift
//  ContentExtractorStoreTests
//

// `canImport` for the macOS 26 SDK of CI, which has no Evaluations module at
// all; `@available` for this package's macOS 15 floor - on each declaration and
// never on the `@Suite`, which the macro rejects (swift-testing#608).
#if os(macOS) && canImport(Evaluations)

import EvaluationCorpus
import Evaluations
import Testing

@Suite("Content extraction quality")
struct ContentExtractionJudgeEvaluationTests {

    private static let dataset = EvaluationDataset(corpus: EvaluationCorpusFile.load())

    @available(macOS 27, *)
    private static let evaluation = ContentExtractionJudgeEvaluation(dataset: dataset)

    /// Without the entitlement, Private Cloud Compute traps the whole test
    /// process on its first request, so the run must not even start.
    @available(macOS 27, *)
    private static var canJudge: Bool {
        EvaluationCorpusFile.canRun && JudgeModel.isReachable
    }

    @available(macOS 27, *)
    @Test("Judged suggestion quality",
          .enabled(if: canJudge),
          .evaluates(evaluation, info: EvaluationCorpusFile.evaluationInfo(for: dataset, judge: "PrivateCloudComputeLanguageModel")))
    func quality() {
        let result = EvaluationContext.current.result

        Attachment.record(result.groupedSummary, named: "aggregates.txt")

        // An unusually verbose judge answer can push one sample out of its
        // window - three calibrated runs dropped 0, 0 and 1 of 26. Beyond that
        // the means below are taken over a corpus that quietly shrank.
        #expect(result.errors.inferenceFailureCount <= 1)
        #expect(result.errors.evaluatorFailureCount <= 1)

        // Both floors are smoke alarms, not precision gates: the judge drifts
        // ~0.15 on identical input, and style has ranged 2.73-3.00.
        #expect(result.aggregateValue(.mean(of: Self.evaluation.styleConformance.metric)) >= 2.60)

        // A fabricated issuer is filed and never noticed, so groundedness is
        // the dimension to climb first.
        #expect(result.aggregateValue(.mean(of: Self.evaluation.groundedness.metric)) >= 3.00)
    }
}

#endif
