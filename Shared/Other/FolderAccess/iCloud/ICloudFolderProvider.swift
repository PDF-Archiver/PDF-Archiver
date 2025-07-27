//
//  ICloudFolderProvider.swift
//  
//
//  Created by Julian Kahnert on 19.08.20.
//

import Foundation

final class ICloudFolderProvider: FolderProvider {

    private static let tempFolderName = "temp"

    let baseUrl: URL
    let folderChangeStream: AsyncStream<[FileChange]>
    private let folderChangeContinuation: AsyncStream<[FileChange]>.Continuation

    private let metadataQuery: NSMetadataQuery

    init(baseUrl: URL) throws {
        self.baseUrl = baseUrl

        let (stream, continuation) = AsyncStream.makeStream(of: [FileChange].self)
        folderChangeStream = stream
        folderChangeContinuation = continuation

        self.metadataQuery = NSMetadataQuery()

        // Filter only documents from the current year and the year before
//        let year = Calendar.current.component(.year, from: Date())
//        let predicate = NSPredicate(format: "(%K LIKE[c] '\(year)-*.pdf') OR (%K LIKE[c] '\(year - 1)-*.pdf')", NSMetadataItemFSNameKey, NSMetadataItemFSNameKey)
        // get all pdf documents
        let predicate = NSPredicate(format: "%K ENDSWITH[c] '.pdf'", NSMetadataItemFSNameKey)

        let notContainsTempPath = NSPredicate(format: "(NOT (%K CONTAINS[c] %@)) AND (NOT (%K CONTAINS[c] %@))", NSMetadataItemPathKey, "/\(ICloudFolderProvider.tempFolderName)/", NSMetadataItemPathKey, "/.Trash/")
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

        /*
         We supply our own serializing queue to the `NSMetadataQuery` so that we
         can perform our own background work in sync with item discovery.
         Note that the operationQueue of the `NSMetadataQuery` must be serial.
         */
        metadataQuery.operationQueue = .main

        Task(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await _ in NotificationCenter.default.notifications(named: .NSMetadataQueryDidFinishGathering) {
                        Self.log.debug("Documents query finished initial fetch.")

                        let details = await self.getFileChangeDetails()

                        // update the archive
                        let changes = details
                            .compactMap(\.self)
                            .map { FileChange.added($0) }
                        self.folderChangeContinuation.yield(changes)
                    }
                }

                group.addTask {
                    for await notification in NotificationCenter.default.notifications(named: .NSMetadataQueryDidUpdate) {
                        let addedMetadataItems = (notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem]) ?? []
                        let updatedMetadataItems = (notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem]) ?? []
                        let removedMetadataItems = (notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem]) ?? []

                        // update the archive
                        let added = addedMetadataItems
                            .compactMap { $0.createDetails() }
                            .map { FileChange.added($0) }
                        let updated = updatedMetadataItems
                            .compactMap { $0.createDetails() }
                            .map { FileChange.updated($0) }
                        let removed = removedMetadataItems
                            .compactMap { $0.createDetails() }
                            .map { FileChange.removed($0.url) }

                        self.folderChangeContinuation.yield(added + updated + removed)
                    }
                }

                metadataQuery.start()
                log.debug("Starting the documents query.")
            }
        }
    }

    deinit {
        Self.log.debug("deinit ICloudFolderProvider")
        metadataQuery.stop()
    }

    private func getFileChangeDetails() -> [FileChange.Details?] {
        self.metadataQuery.disableUpdates()
        var changes: [FileChange.Details?] = []
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
//        guard FileManager.default.fileExists(atPath: url.path) else {
//            log.assertOrCritical("Could not find file at path: \(url.path)")
//            return
//        }

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

extension NSMetadataItem {
    func createDetails() -> FileChange.Details? {
        // get the document path
        guard let documentPath = value(forAttribute: NSMetadataItemURLKey) as? URL else {
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

        var documentStatus: FileChange.DownloadStatus
        switch downloadingStatus {
        case NSMetadataUbiquitousItemDownloadingStatusCurrent, NSMetadataUbiquitousItemDownloadingStatusDownloaded:
            documentStatus = .local
        case NSMetadataUbiquitousItemDownloadingStatusNotDownloaded:

            if let isDownloading = value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? Bool,
                isDownloading {
                let percentDownloaded = (value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? NSNumber)?.doubleValue ?? 0
                documentStatus = .downloading(percent: percentDownloaded)
            } else {
                documentStatus = .remote
            }
        default:
            log.criticalAndAssert("Unkown download status.", metadata: ["status": "\(downloadingStatus)"])
            preconditionFailure("The downloading status '\(downloadingStatus)' was not handled correctly!")
        }

        return FileChange.Details(url: documentPath, sizeInBytes: Double(size), downloadStatus: documentStatus)
    }
}

extension NSMetadataQuery: @unchecked @retroactive Sendable {}
