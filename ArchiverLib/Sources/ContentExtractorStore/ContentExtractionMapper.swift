//
//  ContentExtractionMapper.swift
//  ArchiverLib
//
//  Normalizes the raw model output into the values stored on a document.
//
//  Pure and free of FoundationModels so the post-processing (trimming,
//  slugifying, tag cap) is unit-testable without Apple Intelligence.
//

import ArchiverModels
import Foundation

/// Raw fields as produced by the model, before normalization. Decouples the
/// FoundationModels `@Generable` type from the deterministic mapping so the
/// mapping can be tested with plain values.
struct RawDocumentInformation: Equatable, Sendable {
    var description: String
    var tags: [String]
}

enum ContentExtractionMapper {

    /// Maximum number of tags kept from the model output.
    static let maxTags = 10

    /// Normalize the raw model output: trim the description, and slug-clean the
    /// tags (remove symbols/whitespace) keeping at most `maxTags`.
    static func normalize(_ raw: RawDocumentInformation) -> (specification: String, tags: [String]) {
        let specification = raw.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = raw.tags.prefix(maxTags).map { $0.slugified(withSeparator: "") }
        return (specification, tags)
    }
}
