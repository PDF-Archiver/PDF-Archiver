//
//  DocumentSuggestionCache.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverDatabase
import ComposableArchitecture
import ContentExtractorStore
import Foundation
import SQLiteData

extension SuggestionCache {
    /// The `documentSuggestions` table. Reads go straight to the database; writes go through the
    /// indexer, which stays the read model's only writer
    /// (`docs/adr/0003-database-is-a-derived-read-model.md`). A deleted document takes its
    /// suggestion with it through the foreign key, so nothing has to prune stale entries.
    static var documentSuggestions: SuggestionCache {
        @Dependency(\.archiveIndexer) var archiveIndexer
        @Dependency(\.defaultDatabase) var database

        return SuggestionCache(
            load: { id in
                await withErrorReporting {
                    try await database.read { db in
                        try DocumentSuggestion.find(id).fetchOne(db)
                    }
                }
                .flatMap(\.self)
                .map { Entry(documentID: $0.documentID, specification: $0.specification, tags: $0.tags) }
            },
            save: { entry in
                await archiveIndexer.saveSuggestion(entry.documentID, entry.specification, entry.tags)
            },
            clear: {
                await archiveIndexer.clearSuggestions()
            },
            count: {
                let count = await withErrorReporting {
                    try await database.read { db in
                        try DocumentSuggestion.all.fetchCount(db)
                    }
                }
                return count ?? 0
            }
        )
    }
}
