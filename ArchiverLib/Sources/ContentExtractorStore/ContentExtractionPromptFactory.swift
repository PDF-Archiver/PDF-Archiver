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

    /// Maximum number of characters of the user's custom prompt. Keeps the
    /// custom prompt small enough to always fit into the prompt budget.
    static let maxCustomPromptLength = 500

    /// Conservative characters-per-token factor so the character budget never
    /// exceeds the model's token-based context window.
    private static let charactersPerToken = 2

    /// Tokens reserved for the instruction segments (incl. tag/description
    /// statistics) and the structured response.
    private static let reservedTokens = 1536

    /// Minimum number of occurrences for a tag to be offered to the model.
    static let minTagCount = 3

    /// How many example descriptions are shown to the model.
    static let maxSpecifications = 20

    /// How many distinct existing tags are shown to the model.
    static let maxTags = 30

    /// Hard character cap on each interpolated statistics block.
    static let maxStatLength = 500

    struct DocumentStats: Equatable, Sendable {
        let tags: String
        let specifications: String
    }

    /// Aggregate the existing documents into the tag/description context blocks.
    ///
    /// Tags are sorted by frequency so the prompt is deterministic (testable,
    /// reproducible for evaluations) and the "prefer frequently used tags"
    /// instruction is actually backed by frequency. Only the tag NAMES are
    /// embedded - a `name:count` format would leak the counts into the
    /// model's tag suggestions (e.g. "rechnung3").
    static func documentStats(from documents: [Document]) -> DocumentStats {
        let allTags: [String] = documents.flatMap(\.tags)
        let grouped: [String: [String]] = Dictionary(grouping: allTags) { $0 }
        let counted: [(name: String, count: Int)] = grouped.map { (name: $0.key, count: $0.value.count) }
        let frequent: [(name: String, count: Int)] = counted
            .filter { $0.count >= minTagCount }
            .sorted { lhs, rhs in
                lhs.count != rhs.count ? lhs.count > rhs.count : lhs.name < rhs.name
            }

        let tagsString = frequent
            .prefix(maxTags)
            .map(\.name)
            .joined(separator: ", ")

        let specificationsString = documents
            // Date ties are broken by specification so the prompt stays
            // deterministic even for same-day documents.
            .sorted { lhs, rhs in
                lhs.date != rhs.date ? lhs.date > rhs.date : lhs.specification < rhs.specification
            }
            .prefix(maxSpecifications)
            .map(\.specification)
            .joined(separator: "\n")

        return DocumentStats(tags: tagsString, specifications: specificationsString)
    }

    // MARK: - Instruction segments

    static let taskInstruction = """
    Your task is to archive documents by analyzing their content and generating appropriate descriptions and tags.
    If the document content does not contain enough information to create good tags/description, you MUST NOT hallucinate them - just return empty values.
    """

    static func tagsInstruction(stats: DocumentStats) -> String {
        """
        Tags MUST ALWAYS use existing tags from the system whenever applicable.
        Prefer the existing tags, ordered by most frequently used first: \(stats.tags.prefix(maxStatLength))
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

    /// Character budget for the user prompt (custom prompt + document text),
    /// derived from the model's token-based context window
    /// (`SystemLanguageModel.contextSize`).
    static func promptBudget(contextSize: Int) -> Int {
        max(0, (contextSize - reservedTokens) * charactersPerToken)
    }

    /// Cap the user's custom prompt at ``maxCustomPromptLength`` so it always
    /// fits into the budget.
    static func truncatedCustomPrompt(_ customPrompt: String?) -> String? {
        guard let customPrompt else { return nil }
        return String(customPrompt.prefix(maxCustomPromptLength))
    }

    /// Truncate the document text to fit the prompt budget, leaving room for
    /// the optional custom prompt.
    static func truncatedText(from text: String, customPromptLength: Int, budget: Int) -> String {
        let availableTextLength = budget - customPromptLength
        return String(text.prefix(max(0, availableTextLength)))
    }
}
