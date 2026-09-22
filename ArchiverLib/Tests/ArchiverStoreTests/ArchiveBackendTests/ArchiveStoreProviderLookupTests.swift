//
//  ArchiveStoreProviderLookupTests.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 21.09.26.
//

import Dependencies
import Foundation
import Testing

@testable import ArchiverStore

/// Reproduces the reported bug without needing a real iCloud container: a provider's `baseUrl`
/// carrying a stray `/private` prefix (what the unfixed `iCloudDriveURL` used to hand back) must
/// still match a document URL spelled the normalized way (what the database always stores).
@Suite
struct ArchiveStoreProviderLookupTests {
    @Test
    func getProviderMatchesADocumentEvenWhenTheProvidersBaseUrlCarriesAStrayPrivatePrefix() async throws {
        let cleanRoot = URL(filePath: NSTemporaryDirectory()).appending(component: "provider-lookup-\(UUID().uuidString)")
        let cleanArchive = cleanRoot.appending(component: "Archive")
        let cleanUntagged = cleanArchive.appending(component: "untagged")
        try FileManager.default.createDirectory(at: cleanUntagged, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: cleanRoot) }

        let dirtyArchive = URL(filePath: "/private" + cleanArchive.path())
        let dirtyUntagged = URL(filePath: "/private" + cleanUntagged.path())

        let file = cleanUntagged.appending(component: "document.pdf")

        try await withDependencies {
            $0.archiveIndexer.setObservedRoots = { _ in 0 }
            $0.archiveIndexer.reconcile = { _, _, _ in }
        } operation: {
            let store = ArchiveStore()
            await store.update(archiveFolder: dirtyArchive, untaggedFolders: [dirtyUntagged])

            try Data("pdf".utf8).write(to: file)

            try await store.delete(url: file)
        }

        #expect(!FileManager.default.fileExists(atPath: file.path()))
    }
}
