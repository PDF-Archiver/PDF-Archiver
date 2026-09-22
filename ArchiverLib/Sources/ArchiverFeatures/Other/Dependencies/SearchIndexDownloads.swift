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
import OSLog
import SQLiteData

/// The opt-in half of indexing: only documents on this device carry text, so a complete index
/// needs the rest downloaded first.
enum SearchIndexDownloads {
    /// Per run. What bounds a run is the time the system grants, not this number - at 25 a
    /// multi-thousand-document archive needed months of nights to arrive.
    private static let batchSize = 250

    static func requestNextBatch() async {
        @Shared(.downloadAllForSearch) var downloadAllForSearch: Bool
        guard downloadAllForSearch else {
            Logger.app.notice("[textindex] Prefetch skipped, downloads are turned off")
            return
        }

        @Dependency(\.archiveStore) var archiveStore
        @Dependency(\.defaultDatabase) var database

        let documents = await withErrorReporting {
            try await database.read { db in
                try Document.notDownloaded(limit: batchSize).fetchAll(db)
            }
        }
        guard let documents else { return }
        Logger.app.notice("[textindex] Prefetch requested", metadata: ["documentCount": "\(documents.count)"])

        // The iCloud daemon finishes these in its own time; the next run indexes them.
        for document in documents {
            do {
                try await archiveStore.startDownloadOf(document.url)
            } catch {
                Logger.app.error("Failed to start search-index prefetch download", metadata: [
                    "documentId": "\(document.id)",
                    "error": "\(LogRedact.describe(error))"
                ])
            }
        }
    }
}
