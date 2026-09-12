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
    static let maxTags = 4

    /// Normalize the raw model output: trim the description, and slug-clean the
    /// tags (remove symbols/whitespace) keeping at most `maxTags`.
    ///
    /// - Parameter vocabulary: Tags the archive already uses. A suggestion
    ///   outside it is dropped: asking the prompt for existing tags only made
    ///   the model cautious rather than accurate, and an invented tag can never
    ///   match what the user filed, so dropping one only removes a wrong answer.
    ///   Pass an empty set to keep every tag, for an archive with no tags yet.
    static func normalize(_ raw: RawDocumentInformation,
                          vocabulary: Set<String> = []) -> (specification: String, tags: [String]) {
        let specification = raw.description.trimmingCharacters(in: .whitespacesAndNewlines)

        var seen = Set<String>()
        let tags = raw.tags
            .map(normalizeTag)
            .filter(isValidTag)
            .filter { seen.insert($0).inserted }
            .filter { vocabulary.isEmpty || vocabulary.contains($0) }
        return (specification, Array(tags.prefix(maxTags)))
    }

    /// Slug-clean a single tag. A trailing `:<count>` (the model echoing usage
    /// statistics) is stripped BEFORE slugifying - slugifying first would merge
    /// the count into the name ("rechnung:3" -> "rechnung3").
    private static func normalizeTag(_ tag: String) -> String {
        var tag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = tag.firstMatch(of: /^(.*?)[:#]\s*\d+$/) {
            tag = String(match.1)
        }
        return tag.slugified(withSeparator: "").lowercased()
    }

    /// Purely numeric tags carry no meaning for the archive (tags with digits
    /// inside a word, e.g. "co2", stay valid).
    private static func isValidTag(_ tag: String) -> Bool {
        !tag.isEmpty && !tag.allSatisfy(\.isNumber)
    }
}
