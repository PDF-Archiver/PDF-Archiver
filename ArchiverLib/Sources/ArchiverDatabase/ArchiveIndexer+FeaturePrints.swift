//
//  ArchiveIndexer+FeaturePrints.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 13.09.26.
//

import ArchiverModels
import Dependencies
import Foundation
import SQLiteData

extension ArchiveIndexer {
    /// Remembers a document's Vision feature print - stage 3's visual retrieval fallback
    /// (`docs/retrieval-augmented-tagging-concept.md`).
    ///
    /// Routed through the indexer so it stays the read model's only writer
    /// (`docs/adr/0003-database-is-a-derived-read-model.md`); the print is derived data like
    /// everything else and a rebuild drops it.
    public func saveFeaturePrint(documentID: Document.ID, encodedObservation: Data, revision: Int) async {
        @Dependency(\.date.now) var now
        await withErrorReporting {
            try await database.write { db in
                try DocumentFeaturePrint
                    .upsert {
                        DocumentFeaturePrint(documentID: documentID,
                                             encodedObservation: encodedObservation,
                                             revision: revision,
                                             createdAt: now)
                    }
                    .execute(db)
            }
        }
    }
}
