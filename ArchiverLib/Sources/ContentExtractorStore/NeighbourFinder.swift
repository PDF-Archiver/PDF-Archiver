//
//  NeighbourFinder.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 13.09.26.
//

import ArchiverModels
import Foundation

/// Where the retrieval neighbours for a document's text come from.
///
/// A seam like `SuggestionCache`: this module must not depend on `ArchiverDatabase`, so the
/// bm25-ranked query lives where the database is available and this only calls it.
nonisolated public struct NeighbourFinder: Sendable {
    /// One retrieval hit: the fields the prompt block renders, plus the score
    /// ``ContentExtractionPromptFactory/neighbourRelevanceFloor`` is applied to.
    public struct Match: Equatable, Sendable {
        public let date: Date
        public let specification: String
        public let tags: [String]
        /// SQLite FTS5 `bm25()` score - more negative is a stronger match. Meaningless for a
        /// visual (stage 3) match, which is never filtered by it.
        public let rank: Double

        public init(date: Date, specification: String, tags: [String], rank: Double) {
            self.date = date
            self.specification = specification
            self.tags = tags
            self.rank = rank
        }
    }

    /// Ranked, tagged neighbours for `text`, best match first. `excluding` keeps a re-tag from
    /// retrieving itself as its own nearest neighbour.
    public var find: @Sendable (_ text: String, _ excluding: Document.ID?, _ limit: Int) async -> [Match]

    public init(find: @escaping @Sendable (_ text: String, _ excluding: Document.ID?, _ limit: Int) async -> [Match]) {
        self.find = find
    }

    /// No index available. The caller degrades to the global block, same as an empty result.
    public static let unavailable = NeighbourFinder(find: { _, _, _ in [] })
}
