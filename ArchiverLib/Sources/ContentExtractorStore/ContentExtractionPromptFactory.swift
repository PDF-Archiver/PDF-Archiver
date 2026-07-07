//
//  ContentExtractionPromptFactory.swift
//  ArchiverLib
//
//  Builds the deterministic parts of the content-extraction prompt.
//
//  This type is intentionally pure and free of FoundationModels so the prompt
//  logic can be unit-tested without Apple Intelligence and on any OS version.
//  The actor assembles these segments into FoundationModels `Instructions` /
//  `Prompt` builders; the *content* of every segment lives here.
//

import ArchiverModels
import Foundation

enum ContentExtractionPromptFactory {

    /// Maximum number of document-text characters (instructions excluded) sent
    /// to the model.
    static let maxTotalPromptLength = 3500

    /// Minimum number of occurrences for a tag to be offered to the model.
    static let minTagCount = 3

    /// How many example descriptions are shown to the model.
    static let maxSpecifications = 20

    /// How many distinct existing tags are shown to the model.
    static let maxTags = 30

    /// Hard character cap on each interpolated statistics block.
    static let maxStatLength = 500

    struct DocumentStats: Equatable, Sendable {
        let tagCounts: String
        let specifications: String
    }

    /// Aggregate the existing documents into the tag/description context blocks.
    ///
    /// Tags are sorted by frequency (descending, then alphabetically). The
    /// original implementation relied on `Dictionary` iteration order, which is
    /// non-deterministic — so the "prefer frequently used tags" instruction was
    /// not actually backed by frequency and the prompt changed run-to-run. Sorting
    /// makes the prompt deterministic (testable, reproducible for evaluations) and
    /// honours the instruction's intent.
    static func documentStats(from documents: [Document]) -> DocumentStats {
        let allTags: [String] = documents.flatMap(\.tags)
        let grouped: [String: [String]] = Dictionary(grouping: allTags) { $0 }
        let counted: [(name: String, count: Int)] = grouped.map { (name: $0.key, count: $0.value.count) }
        let frequent: [(name: String, count: Int)] = counted
            .filter { $0.count >= minTagCount }
            .sorted { lhs, rhs in
                lhs.count != rhs.count ? lhs.count > rhs.count : lhs.name < rhs.name
            }

        let formattedTagCounts = frequent
            .prefix(maxTags)
            .map { "\($0.name):\($0.count)" }
            .joined(separator: "\n")
        let tagCountsString = """
        tagName: count
        \(formattedTagCounts)
        """

        let specificationsString = documents
            // Newest first; break date ties by specification so the prompt is
            // fully deterministic even for same-day documents.
            .sorted { lhs, rhs in
                lhs.date != rhs.date ? lhs.date > rhs.date : lhs.specification < rhs.specification
            }
            .prefix(maxSpecifications)
            .map(\.specification)
            .joined(separator: "\n")

        return DocumentStats(tagCounts: tagCountsString, specifications: specificationsString)
    }

    // MARK: - Instruction segments

    static let taskInstruction = """
    Your task is to archive documents by analyzing their content and generating appropriate descriptions and tags.
    If the document content does not contain enough information to create good tags/description, you MUST NOT hallucinate them - just return empty values.
    """

    static func tagsInstruction(stats: DocumentStats) -> String {
        """
        Tags MUST ALWAYS use existing tags from the system whenever applicable.
        Prefer frequently used tags to maintain consistency: \(stats.tagCounts.prefix(maxStatLength))
        If no suitable existing tags are found, create new appropriate tags.
        """
    }

    static func descriptionInstruction(stats: DocumentStats, locale: Locale) -> String {
        """
        The description should provide a concise summary of the document's content (5-10 words maximum).
        You MUST ALWAYS use the user's locale: \(locale.identifier).
        You MUST ALWAYS model your new description after the examples, adapting the style and format to match the current document's content.
        Only use the current document content. DO NOT hallucinate.
        Example descriptions: \(stats.specifications.prefix(maxStatLength))
        """
    }

    // MARK: - User prompt

    /// Truncate the document text to fit the prompt budget, leaving room for the
    /// optional custom prompt.
    static func truncatedText(from text: String, customPromptLength: Int) -> String {
        let availableTextLength = maxTotalPromptLength - customPromptLength
        return String(text.prefix(max(0, availableTextLength)))
    }
}
