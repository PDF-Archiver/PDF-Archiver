//
//  ArchiveStoreDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.25.
//

import ArchiverModels
import ComposableArchitecture
import Foundation
import OSLog

@DependencyClient
public struct ArchiveStoreDependency: Sendable {
    public var reloadDocuments: @Sendable () async throws -> Void
    public var startDownloadOf: @Sendable (URL) async throws -> Void
    public var evictDocumentAt: @Sendable (URL) async throws -> Void
    public var deleteDocumentAt: @Sendable (URL) async throws -> Void
    public var parseFilename: @Sendable (String) async -> (date: Date?, specification: String?, tagNames: [String]?) = { _ in (nil, nil, nil) }
    public var saveDocument: @Sendable (Document, Bool) async throws -> Void
    public var setArchiveStorageType: @Sendable (StorageType) async throws -> Void
}

extension ArchiveStoreDependency: TestDependencyKey {
    public static let previewValue = Self(
        reloadDocuments: { },
        startDownloadOf: { _ in },
        evictDocumentAt: { _ in },
        deleteDocumentAt: { _ in },
        parseFilename: { _ in (nil, nil, nil) },
        saveDocument: { _, _ in },
        setArchiveStorageType: { _ in }
    )

    public static let testValue = Self()
}

extension ArchiveStoreDependency: DependencyKey {
    public static let liveValue = ArchiveStoreDependency(
        reloadDocuments: {
            return try await ArchiveStore.shared.reloadArchiveDocuments()
        },
        // Bypasses `ArchiveStore`/`FolderProviderActor` on purpose: `startDownloadingUbiquitousItem`
        // is itself thread-safe, and every caller only ever passes a document whose `downloadStatus`
        // is already known to be below 1, i.e. an iCloud item - the provider lookup this used to
        // queue behind would only have picked the same iCloud provider back out again.
        startDownloadOf: { url in
            Logger.archiveStore.notice("Requesting iCloud download", metadata: ["document": LogRedact.token(url)])
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
        },
        // Bypasses ArchiveStore/FolderProviderActor on purpose, mirroring `startDownloadOf`: every
        // caller already verified StorageType == .iCloudDrive and downloadStatus == 1.
        evictDocumentAt: { url in
            Logger.archiveStore.notice("Evicting local copy", metadata: ["document": LogRedact.token(url)])
            try FileManager.default.evictUbiquitousItem(at: url)
        },
        deleteDocumentAt: { url in
            try await ArchiveStore.shared.delete(url: url)
        },
        parseFilename: { filename in
            await Document.parseFilename(filename)
        },
        saveDocument: { document, shouldUpdatePdfMetadata in
            try await ArchiveStore.shared.save(document, shouldUpdatePdfMetadata: shouldUpdatePdfMetadata)
        },
        setArchiveStorageType: { type in
            try await ArchiveStore.shared.update(with: type)
        }
    )
}

public extension DependencyValues {
    var archiveStore: ArchiveStoreDependency {
        get { self[ArchiveStoreDependency.self] }
        set { self[ArchiveStoreDependency.self] = newValue }
    }
}
