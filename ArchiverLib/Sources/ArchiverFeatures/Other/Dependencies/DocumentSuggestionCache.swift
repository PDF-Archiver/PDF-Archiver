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
    /// The `documentSuggestions` table. A deleted document takes its suggestion with it through
    /// the foreign key, so nothing has to prune stale entries any more.
    static var documentSuggestions: SuggestionCache {
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.date.now) var now

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
                await withErrorReporting {
                    try await database.write { db in
                        try DocumentSuggestion
                            .upsert {
                                DocumentSuggestion(documentID: entry.documentID,
                                                   specification: entry.specification,
                                                   tags: entry.tags,
                                                   createdAt: now)
                            }
                            .execute(db)
                    }
                }
            },
            clear: {
                await withErrorReporting {
                    try await database.write { db in
                        try DocumentSuggestion.delete().execute(db)
                    }
                }
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
