//
//  EvaluationCorpusFile.swift
//  ContentExtractorStoreTests
//

// `canImport` for the macOS 26 SDK of CI, which has no Evaluations module at
// all; `@available` for this package's macOS 15 floor - on each declaration and
// never on the `@Suite`, which the macro rejects (swift-testing#608).
#if os(macOS) && canImport(Evaluations)

import ContentExtractorStore
import EvaluationCorpus
import Foundation
import Testing

/// The corpus an evaluation run scores against, built by `EvalCorpusBuilder`.
///
/// Kept out of the repository: it carries the text of real documents.
enum EvaluationCorpusFile {

    static let environmentKey = "PDF_ARCHIVER_EVAL_CORPUS"

    /// The corpus to score against - `nil` unless the variable is set and the
    /// file is really there, so a stale path skips the run instead of failing it
    /// against no samples.
    static var url: URL? {
        guard let path = ProcessInfo.processInfo.environment[environmentKey], !path.isEmpty else { return nil }

        let url = URL(filePath: path)
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
    }

    @available(macOS 26, *)
    static var canRun: Bool {
        url != nil && ContentExtractorStore.getAvailability().isUsable
    }

    /// Yields an empty corpus when nothing is configured, so an evaluation can
    /// still be constructed for a test that is then skipped.
    static func load() -> [CorpusDocument] {
        guard let url else { return [] }

        do {
            return try CorpusDocument.corpus(from: Data(contentsOf: url))
        } catch {
            Issue.record("Could not read the corpus at \(url.path(percentEncoded: false)): \(error)")
            return []
        }
    }

    /// Identifies the run in Xcode's evaluation comparison view. Hill-climbing
    /// only works if a run can be told apart from the baseline it is compared to,
    /// so the instructions themselves go in here.
    static func evaluationInfo(for dataset: EvaluationDataset, judge: String? = nil) -> [String: String] {
        let stats = ContentExtractionPromptFactory.documentStats(from: dataset.contextDocuments)
        let locale = ContentExtractionPromptFactory.promptLocale
        var info = [
            "Feature": "Description and tag suggestions for an untagged document",
            "ModelName": "SystemLanguageModel.default",
            "Locale": locale.identifier,
            "TaskInstruction": ContentExtractionPromptFactory.taskInstruction,
            "DescriptionInstruction": ContentExtractionPromptFactory.descriptionInstruction(stats: stats, locale: locale),
            "TagsInstruction": ContentExtractionPromptFactory.tagsInstruction(stats: stats, locale: locale),
            "Samples": "\(dataset.samples.count)",
            "ContextDocuments": "\(dataset.contextDocuments.count)",
            "ArchiveDescriptionWords": "\(dataset.typicalSpecificationWords.lowerBound)-\(dataset.typicalSpecificationWords.upperBound)"
        ]
        info["JudgeModel"] = judge
        return info
    }
}

#endif
