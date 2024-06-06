//
//  ICloudFolderProvider.swift
//  
//
//  Created by Julian Kahnert on 19.08.20.
//

import Foundation

final class ICloudFolderProvider: FolderProvider {

    private static let tempFolderName = "temp"
    private static let workerQueue: OperationQueue = {
        let workerQueue = OperationQueue()

        workerQueue.name = (Bundle.main.bundleIdentifier ?? "PDFArchiver") + ".browserdatasource.workerQueue"
        workerQueue.maxConcurrentOperationCount = 1

        return workerQueue
    }()

    let baseUrl: URL
    private let folderDidChange: FolderChangeHandler

    private let notContainsTempPath = NSPredicate(format: "(NOT (%K CONTAINS[c] %@)) AND (NOT (%K CONTAINS[c] %@))", NSMetadataItemPathKey, "/\(ICloudFolderProvider.tempFolderName)/", NSMetadataItemPathKey, "/.Trash/")
    private var metadataQuery: NSMetadataQuery
    private var firstRun = true

    private let fileManager = FileManager.default

    init(baseUrl: URL, _ handler: @escaping FolderChangeHandler) throws {
        self.baseUrl = baseUrl
        self.folderDidChange = handler
        self.metadataQuery = NSMetadataQuery()

        // Filter only documents from the current year and the year before
//        let year = Calendar.current.component(.year, from: Date())
//        let predicate = NSPredicate(format: "(%K LIKE[c] '\(year)-*.pdf') OR (%K LIKE[c] '\(year - 1)-*.pdf')", NSMetadataItemFSNameKey, NSMetadataItemFSNameKey)
        // get all pdf documents
        let predicate = NSPredicate(format: "%K ENDSWITH[c] '.pdf'", NSMetadataItemFSNameKey)

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
        metadataQuery.operationQueue = Self.workerQueue

        NotificationCenter.default.addObserver(self, selector: #selector(Self.finishGathering(notification:)), name: .NSMetadataQueryDidFinishGathering, object: metadataQuery)
        NotificationCenter.default.addObserver(self, selector: #selector(Self.queryUpdated(notification:)), name: .NSMetadataQueryDidUpdate, object: metadataQuery)

        metadataQuery.start()
        log.debug("Starting the documents query.")
    }

    deinit {
        Self.log.debug("deinit ICloudFolderProvider")
        metadataQuery.stop()
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
        try fileManager.createFolderIfNotExists(url.deletingLastPathComponent())

        // test if the document name already exists in archive, otherwise move it
        if fileManager.fileExists(atPath: url.path) {
            throw FolderProviderError.renameFailedFileAlreadyExists
        }

        try data.write(to: url)
    }

    func startDownload(of url: URL) throws {
//        guard fileManager.fileExists(atPath: url.path) else {
//            log.assertOrCritical("Could not find file at path: \(url.path)")
//            return
//        }

        try fileManager.startDownloadingUbiquitousItem(at: url)
    }

    func fetch(url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func delete(url: URL) throws {
        // trash items (not remove) to let users restore them if needed
        try fileManager.trashItem(at: url, resultingItemURL: nil)
    }

    func rename(from source: URL, to destination: URL) throws {
        guard source != destination else { return }
        try fileManager.createFolderIfNotExists(destination.deletingLastPathComponent())

        // test if the document name already exists in archive, otherwise move it
        if fileManager.fileExists(atPath: destination.path) {
            throw FolderProviderError.renameFailedFileAlreadyExists
        }

        try fileManager.moveItem(at: source, to: destination)
    }

    // MARK: - Helper Functions

    private func update(added: [NSMetadataItem], removed: [NSMetadataItem], updated: [NSMetadataItem]) {
        var changes = [FileChange]()

        changes.append(contentsOf: added.createDetails(FileChange.added))
        changes.append(contentsOf: removed.createDetails(FileChange.removed))
        changes.append(contentsOf: updated.createDetails(FileChange.updated))

        folderDidChange(self, changes)
    }

    static func createDetails(from item: NSMetadataItem) -> FileChange.Details? {
        // get the document path
        guard let documentPath = item.value(forAttribute: NSMetadataItemURLKey) as? URL else {
            log.errorAndAssert("Could not parse Metadata URL.")
            return nil
        }

        // get file size and filename
        guard let size = item.value(forAttribute: NSMetadataItemFSSizeKey) as? Int64 else {
            log.errorAndAssert("Could not parse Metadata Size.")
            return nil
        }
        guard let filename = item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String else {
            log.errorAndAssert("Could not parse Metadata DisplayName.")
            return nil
        }

        // Check if it is a local document. These two values are possible for the "NSMetadataUbiquitousItemDownloadingStatusKey":
        // - NSMetadataUbiquitousItemDownloadingStatusCurrent
        // - NSMetadataUbiquitousItemDownloadingStatusNotDownloaded
        guard let downloadingStatus = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String else {
            log.errorAndAssert("Could not parse Metadata DownloadStatus.")
            return nil
        }

        var documentStatus: FileChange.DownloadStatus
        switch downloadingStatus {
        case "NSMetadataUbiquitousItemDownloadingStatusCurrent", "NSMetadataUbiquitousItemDownloadingStatusDownloaded":
            documentStatus = .local
        case "NSMetadataUbiquitousItemDownloadingStatusNotDownloaded":

            if let isDownloading = item.value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? Bool,
                isDownloading {
                let percentDownloaded = Float(truncating: (item.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? NSNumber) ?? 0)

                documentStatus = .downloading(percent: Double(percentDownloaded / 100))
            } else {
                documentStatus = .remote
            }
        default:
            log.criticalAndAssert("Unkown download status.", metadata: ["status": "\(downloadingStatus)"])
            preconditionFailure("The downloading status '\(downloadingStatus)' was not handled correctly!")
        }

        return FileChange.Details(url: documentPath, filename: filename, size: Int(size), downloadStatus: documentStatus)
    }

    // MARK: - Notifications

    @objc
    private func queryUpdated(notification: NSNotification) {

        log.debug("Documents query update.")
        let changedMetadataItems = (notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem]) ?? []
        let removedMetadataItems = (notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem]) ?? []
        let addedMetadataItems = (notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem]) ?? []

        // update the archive
        update(added: addedMetadataItems, removed: removedMetadataItems, updated: changedMetadataItems)
    }

    @objc
    private func finishGathering(notification: NSNotification) {

        log.debug("Documents query finished initial fetch.")
        guard let metadataQueryResults = metadataQuery.results as? [NSMetadataItem] else { return }

        // update the archive
        update(added: metadataQueryResults, removed: [], updated: [])
    }
}

fileprivate extension Array where Array.Element == NSMetadataItem {
    func createDetails(_ handler: (FileChange.Details) -> FileChange) -> [FileChange] {
        self.compactMap { item -> FileChange? in
            if let details = ICloudFolderProvider.createDetails(from: item) {
                return handler(details)
            } else {
                Self.log.errorAndAssert("Could not create details for item.", metadata: ["item": "\(item)"])
                return nil
            }
        }
    }

    func createDetails(_ handler: (URL) -> FileChange) -> [FileChange] {
        self.createDetails { details in
            handler(details.url)
        }
    }
}
