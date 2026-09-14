//
//  DocumentFeaturePrintStore.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 13.09.26.
//

import ArchiverDatabase
import ComposableArchitecture
import ContentExtractorStore
import Foundation
import SQLiteData
import Vision

extension FeaturePrintCache {
    /// The `documentFeaturePrints` table. Reads go straight to the database; writes go through the
    /// indexer, which stays the read model's only writer
    /// (`docs/adr/0003-database-is-a-derived-read-model.md`). A deleted document takes its
    /// feature print with it through the foreign key, so nothing has to prune stale entries.
    static var documentFeaturePrints: FeaturePrintCache {
        @Dependency(\.archiveIndexer) var archiveIndexer
        @Dependency(\.defaultDatabase) var database

        return FeaturePrintCache(
            load: { id in
                await withErrorReporting {
                    try await database.read { db in
                        try DocumentFeaturePrint.find(id).fetchOne(db)
                    }
                }
                .flatMap(\.self)
                .map { Entry(documentID: $0.documentID, encodedObservation: $0.encodedObservation, revision: $0.revision) }
            },
            save: { entry in
                await archiveIndexer.saveFeaturePrint(entry.documentID, entry.encodedObservation, entry.revision)
            },
            clear: {
                await archiveIndexer.clearFeaturePrints()
            }
        )
    }
}

extension VisualNeighbourFinder {
    /// Backed by `DocumentFeaturePrint.taggedRows(excluding:)`: a linear scan plus
    /// `FeaturePrintObservation.distance(to:)`, cheap enough at archive scale that no vector index
    /// is warranted (`docs/retrieval-augmented-tagging-concept.md`).
    static var documentFeaturePrints: VisualNeighbourFinder {
        @Dependency(\.defaultDatabase) var database

        return VisualNeighbourFinder { documentID, limit in
            let result = await withErrorReporting {
                try await database.read { db -> (DocumentFeaturePrint, [DocumentFeaturePrintRow])? in
                    guard let own = try DocumentFeaturePrint.find(documentID).fetchOne(db) else { return nil }
                    let candidates = try DocumentFeaturePrint.taggedRows(excluding: documentID).fetchAll(db)
                    return (own, candidates)
                }
            }
            guard let (own, candidates) = result.flatMap(\.self),
                  own.revision == FeaturePrintCache.currentRevision,
                  let ownObservation = try? PropertyListDecoder().decode(FeaturePrintObservation.self, from: own.encodedObservation) else { return [] }

            let ranked = candidates
                .filter { $0.revision == own.revision }
                .compactMap { row -> (row: DocumentFeaturePrintRow, distance: Double)? in
                    guard let observation = try? PropertyListDecoder().decode(FeaturePrintObservation.self, from: row.encodedObservation),
                          let distance = try? ownObservation.distance(to: observation) else { return nil }
                    return (row, distance)
                }
                .sorted { $0.distance < $1.distance }
                .prefix(limit)

            return ranked.map { entry in
                NeighbourFinder.Match(date: entry.row.document.date,
                                      specification: entry.row.document.specification,
                                      tags: Array(entry.row.document.tags),
                                      rank: entry.distance)
            }
        }
    }
}
