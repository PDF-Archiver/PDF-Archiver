//
//  EvaluationDataset.swift
//  ArchiverLib
//

import ArchiverModels
import ContentExtractorStore
import Foundation

/// Splits a corpus into the archive the model gets to see and the held-out
/// documents it is evaluated on.
///
/// The split exists to keep the evaluation honest: `ContentExtractionPromptFactory`
/// puts the most recent specifications straight into the instructions, so a
/// document that is both context and sample would have its own answer handed to
/// the model.
public struct EvaluationDataset: Sendable {

    /// How many evaluation samples a split aims for - the 20-30 Apple
    /// recommends starting from.
    public static let targetSampleCount = 25

    /// The archive as the prompt sees it - never contains a sample.
    public let contextDocuments: [Document]

    /// Held-out documents to generate suggestions for.
    public let samples: [CorpusDocument]

    /// Every tag the archive already uses, lowercased.
    public let tagVocabulary: Set<String>

    /// Word count band of the archive's own descriptions - the same band the
    /// extraction prompt asks the model for.
    public let typicalSpecificationWords: ClosedRange<Int>

    /// - Parameter stride: Every n-th document of the date-sorted corpus becomes
    ///   a sample. Derived from the corpus size when omitted, so an archive of
    ///   any size still yields roughly ``targetSampleCount`` samples spread
    ///   across all years.
    public init(corpus: [CorpusDocument], stride: Int? = nil) {
        // Filenames start with the ISO date, so sorting them sorts the archive
        // chronologically and keeps the split reproducible across runs.
        let ordered = corpus.sorted { $0.filename < $1.filename }
        // Never below 2: a stride of 1 would turn every document into a sample
        // and leave the prompt without any archive to model its answers on.
        let step = max(2, stride ?? corpus.count / Self.targetSampleCount)

        var context: [CorpusDocument] = []
        var held: [CorpusDocument] = []
        for (index, document) in ordered.enumerated() {
            if index % step == 0 {
                held.append(document)
            } else {
                context.append(document)
            }
        }

        samples = held
        contextDocuments = context.enumerated().map { $1.asArchiveDocument(id: $0) }
        tagVocabulary = Set(context.flatMap(\.tags).map { $0.lowercased() })
        typicalSpecificationWords = ContentExtractionPromptFactory.descriptionWordRange(of: context.map(\.specification))
    }
}
