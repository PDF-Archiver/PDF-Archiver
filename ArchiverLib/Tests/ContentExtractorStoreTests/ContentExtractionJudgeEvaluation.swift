//
//  ContentExtractionJudgeEvaluation.swift
//  ContentExtractorStoreTests
//

// `canImport` for the macOS 26 SDK of CI, which has no Evaluations module at
// all; `@available` for this package's macOS 15 floor - on each declaration and
// never on the `@Suite`, which the macro rejects (swift-testing#608).
#if os(macOS) && canImport(Evaluations)

import ArchiverModels
import ContentExtractorStore
import EvaluationCorpus
import Evaluations
import Foundation
import FoundationModels

/// Scores the part of "suggests in the style of the existing archive" that no
/// heuristic can reach: whether a suggestion reads like the rest of the archive,
/// stays grounded in the document, and files it at a useful level of detail.
///
/// Runs the feature a second time rather than reusing
/// ``ContentExtractionEvaluation``'s outputs. That is safe because extraction
/// samples greedily at temperature 0, so both runs see the same answers.
@available(macOS 27, *)
struct ContentExtractionJudgeEvaluation: Evaluation {

    /// Longest document text handed to the judge.
    ///
    /// The framework already embeds the sample's prompt, so the judge's window
    /// has to hold the whole document plus the reference material and its own
    /// answer. Sits well above the ~4750 characters `ContentExtractorStore`
    /// truncates to, so the suggestion being judged is unaffected - it only
    /// stops a single outlier document from blowing the 4096-token window.
    ///
    /// This bounds the prompt, not the answer: an unusually verbose judge can
    /// still push one dense sample out of the window, which shows up as a
    /// skipped measurement rather than a failure.
    private static let maximumTextLength = 8000

    /// Existing descriptions shown to the judge as the house style.
    private static let styleExampleCount = 25

    /// Existing tags shown to the judge as the archive's vocabulary. Bounded
    /// like the examples: the on-device judge has the same 4096-token window.
    private static let tagVocabularyCount = 60

    let styleConformance = ScoreDimension(
        "Style Conformance",
        description: """
            Whether the suggested description is shaped like the descriptions already in this archive: \
            the same length, the same kind of wording, and naming the same kind of thing.
            """,
        scale: .numeric([
            4: "Indistinguishable from the archive's own descriptions in length and wording.",
            3: "Recognizably the same style with one deviation, such as being noticeably longer or omitting the issuer.",
            2: "A different style: a sentence-like summary, or so terse that it names only a generic document type.",
            1: "Unrelated to the archive's style: prose, commentary about the text, or an empty description."
        ])
    )

    let groundedness = ScoreDimension(
        "Groundedness",
        description: "Whether every part of the suggested description is supported by the document text.",
        scale: .numeric([
            4: "Every detail - issuer, document type, subject - appears in the document text.",
            3: "Supported by the text apart from one imprecise detail.",
            2: "Partly invented: names an issuer or document type the text does not support.",
            1: "Largely fabricated, or describes the text itself instead of the document."
        ])
    )

    let tagGranularity = ScoreDimension(
        "Tag Granularity",
        description: """
            Whether the suggested tags sit at the level of abstraction that makes a document findable again: \
            reusable across documents, yet narrow enough to filter the archive.
            """,
        scale: .numeric([
            4: "Every tag is a filing category that groups this document with others like it.",
            3: "Mostly good filing categories, with one tag too broad or too specific.",
            2: "Several tags are one-off details such as an invoice number, an amount or a date, or match almost every document.",
            1: "The tags are unusable for filing, or none were suggested."
        ])
    )

    let dataset: ArrayLoader<ModelSample<DocumentSuggestion>>

    private let store = ContentExtractorStore()
    private let contextDocuments: [Document]
    private let styleExamples: String
    private let tagVocabulary: String

    init(dataset source: EvaluationDataset) {
        contextDocuments = source.contextDocuments
        styleExamples = source.contextDocuments
            .sorted { $0.date > $1.date }
            .prefix(Self.styleExampleCount)
            .map(\.specification)
            .joined(separator: ", ")
        tagVocabulary = source.tagVocabulary.sorted().prefix(Self.tagVocabularyCount).joined(separator: ", ")
        dataset = ArrayLoader(samples: source.samples.map { document in
            ModelSample(prompt: String(document.text.prefix(Self.maximumTextLength)),
                        expected: DocumentSuggestion(description: document.specification, tags: document.tags))
        })
    }

    func subject(from sample: ModelSample<DocumentSuggestion>) async throws -> ModelSubject<DocumentSuggestion> {
        let info = try await store.extract(from: sample.promptDescription, with: contextDocuments)
        return ModelSubject(value: DocumentSuggestion(description: info?.specification ?? "",
                                                      tags: info?.tags ?? []))
    }

    var evaluators: Evaluators {
        ModelJudgeEvaluator(
            judge: JudgeModel.selected,
            dimensions: [styleConformance, groundedness, tagGranularity],
            prompt: ModelJudgePrompt(
                instructions: """
                    You are evaluating description and tag suggestions for PDF Archiver, an app that files \
                    scanned documents. Every filed document is stored under the filename \
                    `yyyy-mm-dd--description__tag1_tag2.pdf`, so the description becomes a short hyphenated \
                    slug and the tags become the vocabulary the user browses and searches.

                    The user's existing archive defines the house style. Judge a suggestion by how well it \
                    fits into that archive, not by how well it reads as a summary of the document: a long, \
                    fluent sentence is a worse suggestion than a terse slug that matches the neighbours. \
                    Suggestions are written in \(ContentExtractionPromptFactory.promptLocale.identifier).
                    """,
                evaluationTarget: { value in
                    """
                    Suggested description: \(value.description.isEmpty ? "(none)" : value.description)
                    Suggested tags: \(value.tags.isEmpty ? "(none)" : value.tags.joined(separator: ", "))
                    """
                },
                reference: { input, _ in
                    [
                        "Descriptions already in this archive": styleExamples,
                        "Tags already in this archive": tagVocabulary,
                        "Description the user filed this document under": input.expected?.description ?? "unknown",
                        "Tags the user filed this document under": input.expected?.tags.joined(separator: ", ") ?? "unknown"
                    ]
                }
            )
        )
    }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        aggregator.group("Quality") { group in
            group.computeMean(of: styleConformance.metric)
            group.computeStandardDeviation(of: styleConformance.metric)
            group.computeMean(of: groundedness.metric)
            group.computeStandardDeviation(of: groundedness.metric)
            group.computeMean(of: tagGranularity.metric)
            group.computeStandardDeviation(of: tagGranularity.metric)
        }
    }
}

/// Which model scores the suggestions.
///
/// Private Cloud Compute, and nothing else. Apple's guidance is a judge at least
/// as capable as the judged model, and the on-device one is measurably not: on
/// identical suggestions it scored style 3.5-3.7 where Private Cloud Compute
/// said 2.85-3.00. Keeping it as a fallback meant two calibrations, and the
/// weaker judge failing a run the better one passed.
@available(macOS 27, *)
enum JudgeModel {

    static var selected: any LanguageModel {
        PrivateCloudComputeLanguageModel()
    }

    /// A SwiftPM test bundle is ad-hoc signed and can never carry the managed
    /// entitlement, so a run from there has to skip rather than trap.
    static var isReachable: Bool {
        guard CloudComputeEntitlement.isGranted else { return false }

        if case .available = PrivateCloudComputeLanguageModel().availability { return true }
        return false
    }
}

#endif
