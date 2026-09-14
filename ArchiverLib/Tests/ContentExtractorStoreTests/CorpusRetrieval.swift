//
//  CorpusRetrieval.swift
//  ContentExtractorStoreTests
//
//  Seeds a private, in-memory `ArchiverDatabase` from an evaluation corpus's own context
//  documents, and returns a `NeighbourFinder` that queries it exactly like the live app's
//  `NeighbourFinder.documentTexts` queries the real one.
//
//  Deliberately NOT behind `#if canImport(Evaluations)`: this is where the actual seeding and
//  query logic lives, so it compiles and is tested on every machine, including this one. The
//  Evaluations-gated `ContentExtractionEvaluation` only calls it - see that file for why.
//

import ArchiverDatabase
import ArchiverModels
import ContentExtractorStore
import Dependencies
import Foundation
import IssueReporting
import SQLiteData

enum CorpusRetrieval {
    /// Opens a fresh in-memory database, tags `documents` into it (each keyed by its own `id`,
    /// looked up in `texts`), and returns a `NeighbourFinder` over that database.
    ///
    /// Never throws: a corpus scoring run should degrade to no retrieval rather than fail
    /// outright over a seeding problem, matching how the live app's `.unavailable` finder
    /// degrades to the global block. A reported issue still marks the failure loudly.
    static func neighbourFinder(seededWith documents: [Document], texts: [Document.ID: String]) -> NeighbourFinder {
        guard let database = openSeededDatabase(documents: documents, texts: texts) else { return .unavailable }

        return NeighbourFinder { text, excluding, limit in
            guard let ftsQuery = DocumentText.orQuery(from: text) else { return [] }

            let rows = await withErrorReporting {
                try await database.read { db in
                    try Document.neighbours(matchingFTSQuery: ftsQuery, excluding: excluding, limit: limit).fetchAll(db)
                }
            }
            return (rows ?? []).map { row in
                NeighbourFinder.Match(date: row.document.date,
                                      specification: row.document.specification,
                                      tags: Array(row.document.tags),
                                      rank: row.rank)
            }
        }
    }

    /// Migrates a fresh database and writes every document plus its text in one transaction.
    private static func openSeededDatabase(documents: [Document], texts: [Document.ID: String]) -> (any DatabaseWriter)? {
        withErrorReporting {
            let database = try withDependencies {
                try $0.bootstrapDatabase()
            } operation: {
                Dependency(\.defaultDatabase).wrappedValue
            }

            try database.write { db in
                for document in documents {
                    try Document.insert { document }.execute(db)
                    if let body = texts[document.id] {
                        try DocumentText.insert { DocumentText(rowid: document.id, body: body) }.execute(db)
                    }
                }
            }
            return database
        }
    }
}
