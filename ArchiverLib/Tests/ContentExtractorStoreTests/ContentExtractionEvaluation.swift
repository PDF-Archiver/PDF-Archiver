//
//  ContentExtractionEvaluation.swift
//  ContentExtractorStoreTests
//

// `canImport` for the macOS 26 SDK of CI, which has no Evaluations module at
// all; `@available` for this package's macOS 15 floor - on each declaration and
// never on the `@Suite`, which the macro rejects (swift-testing#608).
#if os(macOS) && canImport(Evaluations)

import ArchiverModels
@testable import ContentExtractorStore
import EvaluationCorpus
import Evaluations
import Foundation

/// What the tagging form would offer the user, as the evaluation sees it.
struct DocumentSuggestion: Codable, Equatable, Sendable {
    var description: String
    var tags: [String]
}

/// Scores the real extraction feature against documents the user has already
/// filed: the filename is the ground truth, the prompt never gets to see it.
///
/// Everything here is measurable in code. Whether a suggestion *reads* like the
/// rest of the archive is the judge's job - see ``ContentExtractionJudgeEvaluation``.
@available(macOS 27, *)
struct ContentExtractionEvaluation: Evaluation {

    /// Tag count the extraction instructions ask the model for.
    private static let requestedTagCount = 2...4

    let dataset: ArrayLoader<ModelSample<DocumentSuggestion>>

    let tagF1 = Metric("Tag F1")
    let tagPrecision = Metric("Tag Precision")
    let tagRecall = Metric("Tag Recall")
    let tagsFromArchive = Metric("Tags From Archive Vocabulary")
    let tagCountRequested = Metric("Tag Count In Requested Range")
    let tagCount = Metric("Tag Count")
    let descriptionWords = Metric("Description Word Count")
    let descriptionLength = Metric("Description Length Matches Archive")
    let suggestionOffered = Metric("Suggestion Offered")
    let noMetaCommentary = Metric("No Meta Commentary")
    let descriptionAvoidsTags = Metric("Description Avoids Tag Words")

    /// Runs the extraction through Private Cloud Compute with the first page
    /// attached, instead of the shipped on-device path.
    ///
    /// Measured on this corpus: tag F1 0.43 -> 0.52, recall 0.38 -> 0.51, and
    /// the two documents Private Cloud Compute otherwise leaves unanswered come
    /// back. Off by default - the app deliberately keeps documents on device.
    static let usesCloudCompute = false

    private let store: ContentExtractorStore
    private let contextDocuments: [Document]
    private let tagVocabulary: Set<String>
    private let typicalDescriptionWords: ClosedRange<Int>

    init(dataset source: EvaluationDataset) {
        if Self.usesCloudCompute {
            let pages = source.samples.reduce(into: [String: String]()) { $0[$1.text] = $1.filename }
            store = ContentExtractorStore(cache: ContentExtractorCache(cacheDirectory: URL(filePath: NSTemporaryDirectory()).appending(path: "eval-cache")),
                                          availability: { .available },
                                          respond: CloudExtraction.responder(sendsWholeDocument: true, pageSources: pages))
        } else {
            store = ContentExtractorStore()
        }
        contextDocuments = source.contextDocuments
        tagVocabulary = source.tagVocabulary
        typicalDescriptionWords = source.typicalSpecificationWords
        dataset = ArrayLoader(samples: source.samples.map { document in
            ModelSample(prompt: document.text,
                        expected: DocumentSuggestion(description: document.specification, tags: document.tags))
        })
    }

    func subject(from sample: ModelSample<DocumentSuggestion>) async throws -> ModelSubject<DocumentSuggestion> {
        // Passing no documentId makes `extract` bypass its cache, so every run
        // really exercises the prompt instead of replaying an earlier answer.
        let info = try await store.extract(from: sample.promptDescription, with: contextDocuments)
        return ModelSubject(value: DocumentSuggestion(description: info?.specification ?? "",
                                                      tags: info?.tags ?? []))
    }

    var evaluators: Evaluators {
        Evaluator { sample, subject in
            tagF1.scoring(score(sample, subject).f1Score)
        }
        Evaluator { sample, subject in
            tagPrecision.scoring(score(sample, subject).precision)
        }
        Evaluator { sample, subject in
            tagRecall.scoring(score(sample, subject).recall)
        }
        Evaluator { _, subject in
            let tags = subject.value.tags
            guard !tags.isEmpty else {
                return tagsFromArchive.failing(rationale: "no tags suggested")
            }

            let unknown = tags.filter { !tagVocabulary.contains($0) }
            guard unknown.isEmpty else {
                return tagsFromArchive.failing(rationale: "new tags: \(unknown.joined(separator: ", "))")
            }
            return tagsFromArchive.passing(rationale: tags.joined(separator: ", "))
        }
        // The tags already carry the document type, so the description has to
        // say what the document is *about*, not repeat a word it already tagged.
        Evaluator { _, subject in
            let repeated = Self.words(of: subject.value.description).filter(subject.value.tags.contains)
            guard repeated.isEmpty else {
                return descriptionAvoidsTags.failing(rationale: "repeats: \(repeated.joined(separator: ", "))")
            }
            return descriptionAvoidsTags.passing(rationale: subject.value.description)
        }
        Evaluator { _, subject in
            let count = subject.value.tags.count
            guard Self.requestedTagCount.contains(count) else {
                return tagCountRequested.failing(rationale: "\(count) tags, asked for \(Self.requestedTagCount.lowerBound)-\(Self.requestedTagCount.upperBound)")
            }
            return tagCountRequested.passing(rationale: "\(count) tags")
        }
        Evaluator { _, subject in
            tagCount.scoring(Double(subject.value.tags.count))
        }
        Evaluator { _, subject in
            descriptionWords.scoring(Double(Self.wordCount(of: subject.value.description)))
        }
        Evaluator { _, subject in
            let words = Self.wordCount(of: subject.value.description)
            guard typicalDescriptionWords.contains(words) else {
                return descriptionLength.failing(rationale: "\(words) words, the archive uses \(typicalDescriptionWords.lowerBound)-\(typicalDescriptionWords.upperBound)")
            }
            return descriptionLength.passing(rationale: "\(words) words")
        }
        Evaluator { _, subject in
            let suggestion = subject.value
            guard !suggestion.description.isEmpty, !suggestion.tags.isEmpty else {
                return suggestionOffered.failing(rationale: "description: '\(suggestion.description)', \(suggestion.tags.count) tags")
            }
            return suggestionOffered.passing()
        }
        Evaluator { _, subject in
            let description = subject.value.description
            guard !ArchiveStyle.containsMetaCommentary(description) else {
                return noMetaCommentary.failing(rationale: "describes the text, not the document: '\(description)'")
            }
            return noMetaCommentary.passing()
        }
    }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        aggregator.group("Tags") { group in
            group.computeMean(of: tagF1)
            group.computeMean(of: tagPrecision)
            group.computeMean(of: tagRecall)
            group.computeMean(of: tagsFromArchive)
            group.computeMean(of: tagCountRequested)
            group.computeMean(of: tagCount)
            group.computeStandardDeviation(of: tagCount)
        }
        aggregator.group("Description") { group in
            group.computeMean(of: descriptionLength)
            group.computeMean(of: descriptionWords)
            group.computeStandardDeviation(of: descriptionWords)
            group.computeMean(of: descriptionAvoidsTags)
        }
        aggregator.group("Safety") { group in
            group.computeMean(of: suggestionOffered)
            group.computeMean(of: noMetaCommentary)
        }
    }

    // MARK: - Scoring

    private func score(_ sample: ModelSample<DocumentSuggestion>, _ subject: ModelSubject<DocumentSuggestion>) -> TagScore {
        TagScore(suggested: Set(subject.value.tags), expected: Set(sample.expected?.tags ?? []))
    }

    /// Descriptions are compared in the shape the filename would carry, and
    /// counted by the prompt's own rule, so the metric grades the band the
    /// model was actually asked for.
    /// The description's words in the shape a tag has, so the two can be compared.
    private static func words(of description: String) -> [String] {
        ArchiveStyle.specification(fromDescription: description)
            .components(separatedBy: "-")
            .filter { !$0.isEmpty }
    }

    private static func wordCount(of description: String) -> Int {
        ContentExtractionPromptFactory.wordCount(ofSpecification: ArchiveStyle.specification(fromDescription: description))
    }
}

#endif
