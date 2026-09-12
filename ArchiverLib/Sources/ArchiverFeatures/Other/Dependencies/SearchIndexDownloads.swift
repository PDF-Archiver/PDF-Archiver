//
//  SearchIndexDownloads.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverDatabase
import ArchiverModels
import ComposableArchitecture
import Foundation
import SQLiteData

/// The opt-in half of indexing: only documents on this device carry text, so a complete index
/// needs the rest downloaded first.
enum SearchIndexDownloads {
    /// Per run, so the archive trickles in over several nights instead of in one burst.
    private static let batchSize = 25

    static func requestNextBatch() async {
        @Shared(.downloadAllForSearch) var downloadAllForSearch: Bool
        guard downloadAllForSearch else { return }

        @Dependency(\.archiveStore) var archiveStore
        @Dependency(\.defaultDatabase) var database

        let documents = await withErrorReporting {
            try await database.read { db in
                try Document.notDownloaded(limit: batchSize).fetchAll(db)
            }
        }
        guard let documents else { return }

        // The iCloud daemon finishes these in its own time; the next run indexes them.
        for document in documents {
            try? await archiveStore.startDownloadOf(document.url)
        }
    }
}
