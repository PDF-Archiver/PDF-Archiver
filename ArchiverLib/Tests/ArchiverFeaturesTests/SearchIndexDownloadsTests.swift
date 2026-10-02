//
//  SearchIndexDownloadsTests.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 02.10.26.
//

import ArchiverModels
import ComposableArchitecture
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@testable import ArchiverFeatures

@Suite(.dependencies {
    try $0.bootstrapDatabase()
    $0.defaultAppStorage = .inMemory
})
struct SearchIndexDownloadsTests {
    @Test
    func requestsTheMissingDocumentsUpToTheLimit() async throws {
        try await Self.insertRemoteDocuments(count: 3)
        let requestedURLs = LockIsolated<[URL]>([])

        let skipReason = await withDependencies {
            $0.premium.currentStatus = { .active }
            $0.networkPath.allowsAutomaticDownloads = { true }
            $0.archiveStore.startDownloadOf = { url in requestedURLs.withValue { $0.append(url) } }
        } operation: {
            await SearchIndexDownloads.requestNextBatch(limit: 2)
        }

        #expect(skipReason == nil)
        #expect(requestedURLs.value.count == 2)
    }

    /// Mobile data is spent only on a document the user opened.
    @Test
    func requestsNothingOnAMeteredNetwork() async throws {
        try await Self.insertRemoteDocuments(count: 1)

        let skipReason = await withDependencies {
            $0.premium.currentStatus = { .active }
            $0.networkPath.allowsAutomaticDownloads = { false }
        } operation: {
            await SearchIndexDownloads.requestNextBatch(limit: 2)
        }

        #expect(skipReason == .meteredNetwork)
    }

    @Test
    func requestsNothingWithoutPremium() async throws {
        try await Self.insertRemoteDocuments(count: 1)

        let skipReason = await withDependencies {
            $0.premium.currentStatus = { .inactive }
        } operation: {
            await SearchIndexDownloads.requestNextBatch(limit: 2)
        }

        #expect(skipReason == .noPremium)
    }

    private static func insertRemoteDocuments(count: Int) async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            for index in 0..<count {
                try Document.insert {
                    Document.mock(url: URL(fileURLWithPath: "/archive/2024/remote\(index).pdf"), isTagged: true, downloadStatus: 0)
                }
                .execute(db)
            }
        }
    }
}
