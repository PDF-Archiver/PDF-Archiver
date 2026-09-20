//
//  AppProjection.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverDatabase
import ArchiverModels
import Foundation
import SQLiteData

/// Everything the tab bar, the toolbar and the widget derive from the archive.
///
/// One request rather than five: a reconcile writes all of these in one transaction, so they
/// change together.
struct AppProjection: Equatable, Sendable {
    var isReconciling = false
    var untaggedCount = 0
    /// Every document, tagged or not - the widget and the statistics count all of them.
    var yearCounts: [Int: Int] = [:]
    /// Tagged only: an untagged scan falls back to its creation-date year, which must not
    /// appear in the tab bar.
    var taggedYears: [Int] = []
    var topTags: [String] = []
}

struct AppProjectionRequest: FetchKeyRequest {
    /// How many years and tags the tab bar and the search suggestions offer.
    private static let suggestionLimit = 5

    func fetch(_ db: Database) throws -> AppProjection {
        let years = try Document.yearCounts(taggedOnly: false).fetchAll(db)
        return AppProjection(
            isReconciling: try IndexerState
                .find(IndexerState.singletonID)
                .select(\.isReconciling)
                .fetchOne(db) ?? false,
            untaggedCount: try Document.untaggedCount.fetchOne(db) ?? 0,
            yearCounts: Dictionary(years.map { ($0.year, $0.count) }, uniquingKeysWith: +),
            taggedYears: try Document.yearCounts(taggedOnly: true)
                .fetchAll(db)
                .prefix(Self.suggestionLimit)
                .map(\.year),
            topTags: try DocumentTag.counts(taggedOnly: true, limit: Self.suggestionLimit)
                .fetchAll(db)
                .map(\.tag)
        )
    }
}
