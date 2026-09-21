//
//  AppStateLogTests.swift
//  ArchiverLib
//

import ArchiverModels
import ComposableArchitecture
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@testable import ArchiverFeatures

@Suite(.dependencies { try $0.bootstrapDatabase() })
struct AppStateLogTests {
    @Test
    func theSnapshotCountsWhatTheArchiveHolds() async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try Document.insert {
                Document.mock(url: URL(fileURLWithPath: "/archive/2024/2024-01-01--a__tag.pdf"), isTagged: true, downloadStatus: 1)
                Document.mock(url: URL(fileURLWithPath: "/archive/untagged/scan1.pdf"), isTagged: false, downloadStatus: 1)
                Document.mock(url: URL(fileURLWithPath: "/archive/2023/2023-01-01--b__tag.pdf"), isTagged: true, downloadStatus: 0)
            }
            .execute(db)
        }

        let snapshot = await withDependencies {
            $0.archiveIndexer.pendingTextCount = { 7 }
        } operation: {
            await AppStateLog.snapshot()
        }

        #expect(snapshot["documentCount"] == "3")
        #expect(snapshot["untaggedCount"] == "1")
        #expect(snapshot["notDownloadedCount"] == "1")
        #expect(snapshot["pendingTextCount"] == "7")
    }

    @Test
    func theStorageNameLeavesOutACustomFoldersPath() throws {
        #expect(AppStateLog.storageName(.local(URL(fileURLWithPath: "/Users/someone/Secret Archive"))) == "local")
        #expect(AppStateLog.storageName(.iCloudDrive) == "iCloudDrive")
        #expect(AppStateLog.storageName(nil) == "none")
    }
}
