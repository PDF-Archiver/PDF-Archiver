//
//  ICloudFolderProvider.swift
//  
//
//  Created by Julian Kahnert on 19.08.20.
//

import ArchiverModels
import Foundation
import Shared

final class ICloudFolderProvider: FolderProvider {

    private static let tempFolderName = "temp"

    let baseUrl: URL
    let currentDocumentsStream: AsyncStream<[DocumentInformation]>
    private let currentDocumentsStreamContinuation: AsyncStream<[DocumentInformation]>.Continuation

    private let metadataQuery: NSMetadataQuery

    private var currentDocuments: [Int: DocumentInformation] = [:]
    private var lastDocuments: [DocumentInformation]?
    private var observationTask: Task<Void, Never>?
    /// `nonisolated(unsafe)` so `deinit` can still hand them back: they are written in `init` and
    /// `stop()` under the actor, and `deinit` by definition holds the last reference.
    nonisolated(unsafe) private var notificationTokens: [any NSObjectProtocol] = []

    init(baseUrl: URL) throws {
        self.baseUrl = baseUrl

        let (stream, continuation) = AsyncStream.makeStream(of: [DocumentInformation].self)
        currentDocumentsStream = stream
        currentDocumentsStreamContinuation = continuation

        self.metadataQuery = NSMetadataQuery()

        // get all pdf documents
        let predicate = NSPredicate(format: "%K ENDSWITH[c] '.pdf'", NSMetadataItemFSNameKey)

        let notContainsTempPath = NSPredicate(format: "(NOT (%K CONTAINS[c] %@)) AND (NOT (%K CONTAINS[c] %@))", NSMetadataItemPathKey, "/\(Self.tempFolderName)/", NSMetadataItemPathKey, "/.Trash/")
        metadataQuery.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, notContainsTempPath] )

        // update the file status 3 times per second, while downloading
        metadataQuery.notificationBatchingInterval = 0.3

        /*
         Ask for both in-container documents and external documents so that
         the user gets to interact with all the documents she or he has ever
         opened in the application, without having to pull the document picker
         again and again.
         */
        metadataQuery.searchScopes = [
            NSMetadataQueryUbiquitousDocumentsScope
        ]

        // the operationQueue of the `NSMetadataQuery` must be serial - we use the main queue
        metadataQuery.operationQueue = .main

        // Registered here, synchronously and before the query starts: `DidFinishGathering` is posted
        // exactly once, and a query that finished before an `await`ed loop began iterating would
        // post it into the void - this provider would then never yield a single snapshot.
        let (gathered, gatheredContinuation) = AsyncStream.makeStream(of: Void.self)
        let (updates, updatesContinuation) = AsyncStream.makeStream(of: MetadataUpdate.self)
        let center = NotificationCenter.default
        notificationTokens = [
            // Scoped to `metadataQuery`: macOS runs a second provider for the observed folder, and
            // an unscoped observer would merge that folder's items into this one's snapshot.
            center.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: metadataQuery, queue: nil) { _ in
                gatheredContinuation.yield()
            },
            center.addObserver(forName: .NSMetadataQueryDidUpdate, object: metadataQuery, queue: nil) { notification in
                updatesContinuation.yield(MetadataUpdate(notification))
            }
        ]

        observationTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }

            metadataQuery.start()
            log.debug("Starting the documents query.")

            await withTaskGroup(of: Void.self) { group in
                group.addTask { [weak self] in
                    for await _ in gathered {
                        guard let self else { return }
                        Self.log.debug("Documents query finished initial fetch.")

                        let details = await getFileChangeDetails()

                        // update the archive
                        let changes = details
                            .compactMap(\.self)

                        await sendDocuments(added: changes, updated: [], removed: [])
                    }
                }

                group.addTask { [weak self] in
                    for await update in updates {
                        guard let self else { return }
                        await sendDocuments(added: update.added, updated: update.updated, removed: update.removed)
                    }
                }
            }
        }
    }

    deinit {
        Self.log.debug("deinit ICloudFolderProvider")
        observationTask?.cancel()
        notificationTokens.forEach(NotificationCenter.default.removeObserver)
        metadataQuery.stop()
    }

    func stop() {
        observationTask?.cancel()
        observationTask = nil
        notificationTokens.forEach(NotificationCenter.default.removeObserver)
        notificationTokens = []
        metadataQuery.stop()
    }

    /// One `DidUpdate`, read on the posting thread: `NSMetadataItem` is not `Sendable` and must not
    /// travel to the observation task.
    private struct MetadataUpdate: Sendable {
        let added: [DocumentInformation]
        let updated: [DocumentInformation]
        let removed: [DocumentInformation]

        init(_ notification: Notification) {
            func details(_ key: String) -> [DocumentInformation] {
                (notification.userInfo?[key] as? [NSMetadataItem] ?? []).compactMap { $0.createDetails() }
            }
            added = details(NSMetadataQueryUpdateAddedItemsKey)
            updated = details(NSMetadataQueryUpdateChangedItemsKey)
            removed = details(NSMetadataQueryUpdateRemovedItemsKey)
        }
    }

    private func sendDocuments(added: [DocumentInformation], updated: [DocumentInformation], removed: [DocumentInformation]) {
        for change in added + updated {
            currentDocuments[change.id] = change
        }
        for change in removed {
            // match removed files by URL - reading the uniqueId (a resource value)
            // of an already deleted file would fail
            currentDocuments = currentDocuments.filter { $0.value.url != change.url }
        }
        let documents = Array(currentDocuments.values)
        guard lastDocuments?.sorted() != documents.sorted() else { return }
        currentDocumentsStreamContinuation.yield(documents)
        lastDocuments = documents
    }

    private func getFileChangeDetails() -> [DocumentInformation?] {
        self.metadataQuery.disableUpdates()
        var changes: [DocumentInformation?] = []
        for index in 0..<self.metadataQuery.resultCount {
            guard let result = self.metadataQuery.result(at: index) as? NSMetadataItem else {
                assertionFailure("Could not cast result \(index) to NSMetadataItem")
                continue
            }
            changes.append(result.createDetails())
        }
        self.metadataQuery.enableUpdates()
        return changes
    }

    // MARK: - API

    static func canHandle(_ url: URL) -> Bool {
        guard let cloudUrl = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            // this is a valid situation, if no iCloud Drive is available
            return false
        }
        return url.path.starts(with: cloudUrl.path)
    }

    func save(data: Data, at url: URL) throws {
        try FileManager.default.createFolderIfNotExists(url.deletingLastPathComponent())

        // test if the document name already exists in archive, otherwise move it
        if FileManager.default.fileExists(atPath: url.path) {
            throw FolderProviderError.renameFailedFileAlreadyExists
        }

        try data.write(to: url)
    }

    func startDownload(of url: URL) throws {
        try FileManager.default.startDownloadingUbiquitousItem(at: url)
    }

    func fetch(url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func delete(url: URL) throws {
        // trash items (not remove) to let users restore them if needed
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    func rename(from source: URL, to destination: URL) throws {
        guard source != destination else { return }
        try FileManager.default.createFolderIfNotExists(destination.deletingLastPathComponent())

        // test if the document name already exists in archive, otherwise move it
        if FileManager.default.fileExists(atPath: destination.path) {
            throw FolderProviderError.renameFailedFileAlreadyExists
        }

        try FileManager.default.moveItem(at: source, to: destination)
    }
}

extension NSMetadataItem: nonisolated Log {
    nonisolated func createDetails() -> DocumentInformation? {
        // get the document path
        guard let documentUrl = value(forAttribute: NSMetadataItemURLKey) as? URL else {
            log.errorAndAssert("Could not parse Metadata URL.")
            return nil
        }

        // get file size and filename
        guard let size = value(forAttribute: NSMetadataItemFSSizeKey) as? Int64 else {
            log.errorAndAssert("Could not parse Metadata Size.")
            return nil
        }

        // Check if it is a local document. These two values are possible for the "NSMetadataUbiquitousItemDownloadingStatusKey":
        // - NSMetadataUbiquitousItemDownloadingStatusCurrent
        // - NSMetadataUbiquitousItemDownloadingStatusNotDownloaded
        guard let downloadingStatus = value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String else {
            log.errorAndAssert("Could not parse Metadata DownloadStatus.")
            return nil
        }

        var documentStatus: Double
        switch downloadingStatus {
        case NSMetadataUbiquitousItemDownloadingStatusCurrent, NSMetadataUbiquitousItemDownloadingStatusDownloaded:
            // local
            documentStatus = 1

        case NSMetadataUbiquitousItemDownloadingStatusNotDownloaded:

            let minValue = 0.0
            if let isDownloading = value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? Bool,
                isDownloading {
                let percentDownloaded = (value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? NSNumber)?.doubleValue ?? 0
                documentStatus = max(percentDownloaded / 100, minValue)
            } else {
                // remote
                documentStatus = minValue
            }

        default:
            // do not crash on future/unknown status values - just skip this item
            log.criticalAndAssert("Unkown download status.", metadata: ["status": "\(downloadingStatus)"])
            return nil
        }

        // The metadata attributes answer before a download; the URL resource values of an
        // undownloaded item return stub data.
        let normalizedUrl = documentUrl.normalized()
        guard let id = normalizedUrl.uniqueId() else {
            log.errorAndAssert("Could not fetch unique id from url.")
            return nil
        }

        return DocumentInformation(id: id,
                                   url: normalizedUrl,
                                   downloadStatus: documentStatus,
                                   sizeInBytes: Double(size),
                                   creationDate: value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date,
                                   contentModificationDate: value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date)
    }
}

extension NSMetadataQuery: @unchecked @retroactive Sendable {}
