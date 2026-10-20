//
//  NeighbourVote.swift
//  ArchiverLib
//
//  Adds the tags the retrieved neighbours agree on, which the model reads in the
//  prompt and does not copy.
//
//  Pure and free of FoundationModels, like the mapper it runs next to.
//

import Foundation

/// Adds the tags the document's nearest neighbours agree on.
///
/// Roughly half the filed tags are filing conventions the document text never states, so no
/// wording reaches them - but the retrieved neighbours carry them in their filenames, and the
/// model leaves them there: a top-5 neighbour holds the expected tag on 84% of samples.
/// Weighting each neighbour by its bm25 score and adding every tag above half the total weight
/// raised tag F1 from 0.530 to 0.690 in simulation, and it fills the ~7% of answers the model
/// leaves without any tag.
enum NeighbourVote {

    /// A tag needs this share of the neighbours' bm25 weight to be added.
    ///
    /// A lone neighbour has share 1 and is copied; five disagreeing ones add nothing.
    static let minimumShare = 0.5

    /// `tags` plus every tag the neighbours carry with at least ``minimumShare`` of their weight.
    ///
    /// - Parameter tags: The model's tags, kept in order and never dropped - this only ever
    ///   widens a suggestion, so a wrong tag stays wrong and a right one stays.
    /// - Parameter neighbours: The same survivors the prompt rendered, at most five.
    static func widen(_ tags: [String],
                      with neighbours: [NeighbourFinder.Match],
                      maxTags: Int = ContentExtractionMapper.maxTags) -> [String] {
        // bm25 ranks are negative; a non-negative one comes from the visual fallback channel,
        // whose neighbours share a layout rather than a filing convention.
        guard !neighbours.isEmpty, neighbours.allSatisfy({ $0.rank < 0 }) else { return tags }

        let totalWeight = neighbours.reduce(0.0) { $0 - $1.rank }
        var weightPerTag: [String: Double] = [:]
        for neighbour in neighbours {
            for tag in Set(neighbour.tags.map { $0.lowercased() }) {
                weightPerTag[tag, default: 0] -= neighbour.rank
            }
        }

        let suggested = Set(tags.map { $0.lowercased() })
        // Name breaks a weight tie so the suggestion is reproducible across runs.
        let candidates = weightPerTag
            .filter { !suggested.contains($0.key) && $0.value / totalWeight >= minimumShare }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map(\.key)

        return Array((tags + candidates).prefix(maxTags))
    }
}
