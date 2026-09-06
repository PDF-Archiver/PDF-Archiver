//
//  ArchiveStoreDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.25.
//

import ArchiverModels
import ComposableArchitecture
import Foundation

@DependencyClient
public struct ArchiveStoreDependency: Sendable {
    public var reloadDocuments: @Sendable () async throws -> Void
    public var startDownloadOf: @Sendable (URL) async throws -> Void
    public var deleteDocumentAt: @Sendable (URL) async throws -> Void
    public var parseFilename: @Sendable (String) async -> (date: Date?, specification: String?, tagNames: [String]?) = { _ in (nil, nil, nil) }
    public var saveDocument: @Sendable (Document, Bool) async throws -> Void
    public var setArchiveStorageType: @Sendable (StorageType) async throws -> Void
}

extension ArchiveStoreDependency: TestDependencyKey {
    public static let previewValue = Self(
        reloadDocuments: { },
        startDownloadOf: { _ in },
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
        startDownloadOf: { url in
            try await ArchiveStore.shared.startDownload(of: url)
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
