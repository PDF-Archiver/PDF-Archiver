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

public enum ContentExtractionPromptFactory {

    /// Custom-prompt cap for systems that cannot size it per model, and the
    /// floor for the ones that can.
    static let defaultMaxCustomPromptLength = 500

    /// Conservative characters-per-token factor so the character budget never
    /// exceeds the model's token-based context window.
    private static let charactersPerToken = 2

    /// Tokens reserved for the instruction segments (incl. tag/description
    /// statistics), the injected response schema and the structured response.
    private static let reservedTokens = 2048

    /// Minimum number of occurrences for a tag to be offered to the model.
    static let minTagCount = 3

    /// How many example descriptions are shown to the model.
    ///
    /// Deliberately larger than ``maxTags``: this block is the only place the
    /// model sees the archive's own wording, and the judge's complaint about
    /// generic descriptions is a vocabulary problem.
    static let maxSpecifications = 40

    /// How many distinct existing tags are shown to the model.
    ///
    /// Measured optimum: 20 and 45 both score worse, and doubling it to 60 under
    /// a strict "existing tags only" prompt left tag F1 bit-identical while the
    /// model suggested *fewer* tags. A longer list does not raise recall.
    static let maxTags = 30

    /// Description length asked for when the archive is still too empty to have
    /// a style of its own.
    public static let defaultDescriptionWords = 1...10

    /// Fewer filed descriptions than this cannot define a house style: a single
    /// document would collapse the percentile band onto its own word count.
    private static let minimumDescriptionSamples = 10

    /// Percentile band of the archive's description lengths that counts as
    /// typical. Excludes the outer 20% so a couple of unusually terse or
    /// verbose filenames cannot define the house style.
    private static let descriptionLengthPercentiles = (lower: 0.1, upper: 0.9)

    /// A companion rule is only shown when the leading tag is common enough to
    /// mean something and the pairing is near-certain, so the model gets domain
    /// knowledge rather than noise.
    static let minCompanionCount = 5
    static let minCompanionShare = 0.7

    public struct DocumentStats: Equatable, Sendable {
        public let tags: String

        /// Which tags almost always accompany another, as `tag: a, b` lines.
        public let tagCompanions: String
        public let specifications: String

        /// How long the user's own descriptions are, in words.
        public let descriptionWords: ClosedRange<Int>
    }

    /// Aggregate the existing documents into the tag/description context blocks.
    ///
    /// Tags are sorted by frequency so the prompt is deterministic (testable,
    /// reproducible for evaluations) and the "prefer frequently used tags"
    /// instruction is actually backed by frequency. Only the tag NAMES are
    /// embedded - a `name:count` format would leak the counts into the
    /// model's tag suggestions (e.g. "rechnung3").
    public static func documentStats(from documents: [Document]) -> DocumentStats {
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

        // Untagged inbox scans have an empty specification and today's file date,
        // so they would sort to the front and fill the examples with blank lines.
        let specifications = documents
            .filter { !$0.specification.isEmpty }
            // Date ties are broken by specification so the prompt stays
            // deterministic even for same-day documents.
            .sorted { lhs, rhs in
                lhs.date != rhs.date ? lhs.date > rhs.date : lhs.specification < rhs.specification
            }
            .map(\.specification)

        return DocumentStats(tags: tagsString,
                             tagCompanions: companions(of: documents, offered: Set(frequent.prefix(maxTags).map(\.name))),
                             specifications: specifications.prefix(maxSpecifications).joined(separator: "\n"),
                             descriptionWords: descriptionWordRange(of: specifications))
    }

    /// Pairs a tag with the tags it nearly always appears next to.
    ///
    /// Half the tags this archive files never occur in the document text at all
    /// - `baumarkt`, `vanessa`, `steuerrelevant` - but they follow reliably from
    /// ones that do, like `hornbach` or `beihilfe`.
    static func companions(of documents: [Document], offered: Set<String>) -> String {
        var counts: [String: Int] = [:]
        var pairs: [String: [String: Int]] = [:]
        for document in documents {
            let tags = Set(document.tags.map { $0.lowercased() })
            for tag in tags {
                counts[tag, default: 0] += 1
                for other in tags where other != tag {
                    pairs[tag, default: [:]][other, default: 0] += 1
                }
            }
        }

        let lines = offered.sorted().compactMap { tag -> String? in
            guard let total = counts[tag], total >= minCompanionCount else { return nil }

            let sure = (pairs[tag] ?? [:])
                .filter { Double($0.value) / Double(total) >= minCompanionShare }
                .keys.sorted()
            return sure.isEmpty ? nil : "\(tag): \(sure.joined(separator: ", "))"
        }
        return lines.joined(separator: "\n")
    }

    /// The word-count band the archive's own descriptions fall into.
    ///
    /// Asking the model for the length the user already writes beats naming a
    /// fixed number: archives differ, and a prompt that contradicts the examples
    /// right below it teaches the model the wrong shape.
    public static func descriptionWordRange(of specifications: [String]) -> ClosedRange<Int> {
        let counts = specifications.map(wordCount(ofSpecification:)).filter { $0 > 0 }.sorted()
        guard counts.count >= minimumDescriptionSamples else { return defaultDescriptionWords }

        let lower = counts[percentileIndex(descriptionLengthPercentiles.lower, count: counts.count)]
        let upper = counts[percentileIndex(descriptionLengthPercentiles.upper, count: counts.count)]
        return lower...max(lower, upper)
    }

    /// Filed descriptions are hyphenated slugs, so both separators split words.
    public static func wordCount(ofSpecification specification: String) -> Int {
        specification
            .components(separatedBy: CharacterSet(charactersIn: "-_").union(.whitespacesAndNewlines))
            .count { !$0.isEmpty }
    }

    private static func percentileIndex(_ percentile: Double, count: Int) -> Int {
        let index = Int((Double(count - 1) * percentile).rounded())
        return min(max(0, index), count - 1)
    }

    /// Locale the prompt asks the model to answer in.
    ///
    /// German users get `de_DE` explicitly: `Locale.current` on a German system
    /// is often an English-language variant, and the archive is German.
    public static var promptLocale: Locale {
        Locale.current.region == "DE" ? Locale(identifier: "de_DE") : Locale.current
    }

    // MARK: - Instruction segments

    public static let taskInstruction = """
    Your task is to archive documents by analyzing their content and generating appropriate descriptions and tags.
    If the document content does not contain enough information to create good tags/description, you MUST NOT hallucinate them - just return empty values.
    NEVER describe the document text itself or its quality (e.g. "unreadable document text", "garbled text", "no content") - return empty values instead.
    """

    public static func tagsInstruction(stats: DocumentStats, locale: Locale) -> String {
        let companionRules = stats.tagCompanions.isEmpty
            ? ""
            : "\nWhen you pick the tag on the left, these almost always belong with it:\n\(stats.tagCompanions)"
        let existingTags = stats.tags.isEmpty
            ? ""
            : "\nThe existing tags, ordered by most frequently used first: \(stats.tags)"

        return """
        Tags MUST ALWAYS use existing tags from the system whenever applicable.\(existingTags)
        Every tag MUST be supported by the document itself - NEVER add a tag just because it is used often.
        A company or product name spelled with spaces becomes ONE tag without them: "Alte Oldenburger" is the tag alteoldenburger.\(companionRules)
        You MUST ALWAYS use the user's locale: \(locale.identifier).
        Aim for 2-4 tags, but return fewer or none if the document content does not support them.
        """
    }

    public static func descriptionInstruction(stats: DocumentStats, locale: Locale) -> String {
        """
        The description should provide a concise summary of the document's content (\(stats.descriptionWords.lowerBound)-\(stats.descriptionWords.upperBound) words maximum).
        You MUST ALWAYS use the user's locale: \(locale.identifier).
        The tags already name the document type, so the description MUST NOT repeat any word you chose as a tag - name what the document is about instead.
        You MUST ALWAYS model your new description after the examples, adapting the style and format to match the current document's content.
        Only use the current document content. DO NOT hallucinate.
        Example descriptions: \(stats.specifications)
        """
    }

    // MARK: - User prompt

    /// Tokens the user prompt (custom prompt + document text) may occupy, once
    /// the instructions, the schema and the answer have their reserve.
    public static func availableTokens(contextSize: Int) -> Int {
        max(0, contextSize - reservedTokens)
    }

    /// Character budget for the user prompt, derived from the model's
    /// token-based context window (`SystemLanguageModel.contextSize`).
    public static func promptBudget(contextSize: Int) -> Int {
        availableTokens(contextSize: contextSize) * charactersPerToken
    }

    /// The estimated budget, corrected by the ratio measured on a sample of the
    /// actual document text - German prose runs at roughly twice the
    /// conservative ``charactersPerToken``, which the model would otherwise
    /// never get to see. Falls back to the estimate for an unusable sample.
    ///
    /// The ratio is measured on the head of the document and a dense tail can
    /// break it, so the longer cut has to be measured again before it is sent.
    static func calibratedBudget(contextSize: Int, sampleLength: Int, sampleTokens: Int) -> Int {
        let estimate = promptBudget(contextSize: contextSize)
        guard sampleLength > 0, sampleTokens > 0 else { return estimate }

        return estimate * sampleLength / (sampleTokens * charactersPerToken)
    }

    /// Maximum number of characters of the user's custom prompt, derived from
    /// the model's context window. Never below ``defaultMaxCustomPromptLength``,
    /// so a model reporting no usable context cannot collapse the cap to zero.
    static func maxCustomPromptLength(contextSize: Int) -> Int {
        // A quarter of the budget - the document text keeps the other three.
        max(defaultMaxCustomPromptLength, promptBudget(contextSize: contextSize) / 4)
    }

    /// Cap the user's custom prompt so it always fits into the budget.
    static func truncatedCustomPrompt(_ customPrompt: String?, maxLength: Int) -> String? {
        guard let customPrompt else { return nil }
        return String(customPrompt.prefix(maxLength))
    }

    /// Truncate the document text to fit the prompt budget, leaving room for
    /// the optional custom prompt.
    static func truncatedText(from text: String, customPromptLength: Int, budget: Int) -> String {
        let availableTextLength = budget - customPromptLength
        return String(text.prefix(max(0, availableTextLength)))
    }
}
