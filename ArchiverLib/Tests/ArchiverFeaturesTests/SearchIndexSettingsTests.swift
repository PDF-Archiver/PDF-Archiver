//
//  SearchIndexSettingsTests.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverDatabase
import ArchiverModels
import ComposableArchitecture
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@testable import ArchiverFeatures

@MainActor
@Suite(.dependencies { try $0.bootstrapDatabase() })
struct SearchIndexSettingsTests {
    @Test
    func rebuildingTheSearchIndexAsksForAConfirmationFirst() async throws {
        let rebuilt = LockIsolated(false)
        let rescanned = LockIsolated(false)
        let store = TestStore(initialState: SearchIndexSettings.State()) {
            SearchIndexSettings()
        } withDependencies: {
            $0.archiveIndexer.requestRebuild = { rebuilt.setValue(true) }
            $0.archiveStore.reloadDocuments = { rescanned.setValue(true) }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onRebuildTapped)
        #expect(store.state.alert != nil)
        #expect(!rebuilt.value)

        await store.send(.alert(.presented(.confirmRebuild)))
        await store.finish()

        #expect(rebuilt.value)
        #expect(rescanned.value)
    }

    @Test
    func theStatusStartsEmpty() async throws {
        let state = SearchIndexSettings.State()
        try await state.$status.load()

        #expect(state.status.total == 0)
        #expect(state.status.indexed == 0)
        #expect(state.status.lastRun == nil)
    }

    @Test
    func theStatusReadsTheSeededCounts() async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try db.seed {
                Document(id: 1, rootKey: "test", url: URL(filePath: "/a.pdf"), date: Date(timeIntervalSince1970: 0), specification: "a", tags: [], isTagged: true, sizeInBytes: 1, downloadStatus: 1)
                Document(id: 2, rootKey: "test", url: URL(filePath: "/b.pdf"), date: Date(timeIntervalSince1970: 0), specification: "b", tags: [], isTagged: true, sizeInBytes: 1, downloadStatus: 1)
            }
            try DocumentIndexState.insert {
                DocumentIndexState(documentID: 1, sourceSize: 1, sourceModificationDate: nil, indexedAt: Date(timeIntervalSince1970: 0), outcome: .indexed, characterCount: 10, extractorVersion: DocumentIndexState.currentExtractorVersion)
                DocumentIndexState(documentID: 2, sourceSize: 1, sourceModificationDate: nil, indexedAt: Date(timeIntervalSince1970: 0), outcome: .noText, characterCount: 0, extractorVersion: DocumentIndexState.currentExtractorVersion)
            }
            .execute(db)
        }

        let state = SearchIndexSettings.State()
        try await state.$status.load()

        #expect(state.status.total == 2)
        #expect(state.status.indexed == 1)
        #expect(state.status.withoutText == 1)
        #expect(state.status.pending == 0)
    }
}
