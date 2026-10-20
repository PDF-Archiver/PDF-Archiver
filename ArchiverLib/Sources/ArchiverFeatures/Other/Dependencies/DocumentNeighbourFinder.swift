//
//  DocumentNeighbourFinder.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 13.09.26.
//

import ArchiverDatabase
import ComposableArchitecture
import ContentExtractorStore
import Foundation
import SQLiteData

extension NeighbourFinder {
    /// Backed by `Document.neighbours(matchingFTSQuery:excluding:limit:)` - the bm25-ranked query
    /// beside the search field's own (`Document.rankedSearch`), reusing the same `documentTexts`
    /// FTS5 index rather than a second one.
    static var documentTexts: NeighbourFinder {
        @Dependency(\.defaultDatabase) var database

        return NeighbourFinder { text, excluding, limit in
            // No usable term (too short, or empty) - retrieval has nothing to search for, so the
            // caller degrades to the global block without ever issuing a query.
            guard let ftsQuery = DocumentText.orQuery(from: text) else { return [] }

            let rows = await withErrorReporting {
                try await database.read { db in
                    try Document.neighbours(matchingFTSQuery: ftsQuery, excluding: excluding, limit: limit).fetchAll(db)
                }
            }
            return (rows ?? []).map { row in
                Match(date: row.document.date,
                      specification: row.document.specification,
                      tags: Array(row.document.tags),
                      rank: row.rank)
            }
        }
    }
}
