//
//  TagExpansion.swift
//  ArchiverLib
//
//  Widens the model's tag suggestion with a tag the archive says belongs with it,
//  kept only when the document itself names it.
//
//  Pure and free of FoundationModels, like the mapper it runs next to.
//

import ArchiverModels
import Foundation

/// Adds the one tag a suggestion implies but the model did not offer.
///
/// The model suggests ~1.6 tags where this archive files ~2.5, and that gap is the whole
/// recall shortfall. Two archive-side signals close part of it: which tags are filed
/// together, and whether the document names the tag at all. Measured over 154 samples of
/// a 1911-document archive, tag F1 0.487 -> 0.521 (t=2.7), replicated on a second corpus
/// (0.413 -> 0.460, t=3.9).
enum TagExpansion {

    /// How deep the co-occurrence ranking is read before the text filter applies.
    private static let cooccurrenceDepth = 40

    /// How many tags may be added. One, measured: a second costs more precision than the
    /// recall it buys (F1 0.521 vs 0.517), because candidate quality falls off immediately.
    private static let maximumAddedTags = 1

    /// A tag filed alongside *every* `suggested` tag that `text` also names, appended to
    /// `suggested` if there is room below `limit`.
    ///
    /// - Parameter suggested: The model's tags, kept in order and never dropped - this only
    ///   ever widens a suggestion, so a wrong tag stays wrong and a right one stays.
    static func expanded(_ suggested: [String],
                         with documents: [Document],
                         text: String,
                         limit: Int) -> [String] {
        guard !suggested.isEmpty, suggested.count < limit else { return Array(suggested.prefix(limit)) }

        let seed = Set(suggested.map { $0.lowercased() })
        let named = namedTags(in: text)
        let candidates = cooccurring(with: seed, in: documents)
            .prefix(cooccurrenceDepth)
            .filter { named.contains($0) }

        let room = min(limit - suggested.count, maximumAddedTags)
        return suggested + candidates.prefix(room)
    }

    /// Tags sharing a document with *all* of `seed`, most frequent first.
    ///
    /// All, not any: a tag merely filed next to one of the suggestions is right 13% of the
    /// time (30% even after the text filter), below the model's own precision, so adding it
    /// costs more than it gains. Requiring the full set reaches 47%. Same semantics as
    /// `DocumentTag.cooccurring(with:limit:)` in `ArchiverDatabase`.
    private static func cooccurring(with seed: Set<String>, in documents: [Document]) -> [String] {
        var counts: [String: Int] = [:]
        for document in documents {
            let tags = Set(document.tags.map { $0.lowercased() })
            guard seed.isSubset(of: tags) else { continue }

            for tag in tags.subtracting(seed) {
                counts[tag, default: 0] += 1
            }
        }

        // Name breaks a count tie so the suggestion is reproducible across runs.
        return counts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map(\.key)
    }

    /// The document's words in the shape a tag has, so the two can be compared at all -
    /// tags are slugified ("nymane") where the document spells it "NYMÅNE".
    ///
    /// Only ~31% of the tags the model misses are named in the document at all, so this
    /// filter cannot reach the rest - it is what keeps the added tag from being a guess.
    private static func namedTags(in text: String) -> Set<String> {
        Set(text.slugified(withSeparator: " ")
            .lowercased()
            .split(separator: " ")
            .map(String.init))
    }
}
