//
//  DocumentsQuery.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 23.08.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//
/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This is the Browser Query which manages results form an `NSMetadataQuery` to compute which documents to show in the Browser UI / animations to display when cells move.
 */

import UIKit
import os.log

/**
 The delegate protocol implemented by the object that receives our results. We
 pass the updated list of results as well as a set of animations.
 */
protocol DocumentsQueryDelegate: class {
    func documentsQueryResultsDidChangeWithResults(documents: [Document], tags: Set<Tag>)
}

/**
 The DocumentBrowserQuery wraps an `NSMetadataQuery` to insulate us from the
 queueing and animation concerns. It runs the query and computes animations
 from the results set.
 */
class DocumentsQuery: NSObject, Logging {

    // MARK: - Properties
    fileprivate var documents = [Document]()
    fileprivate var tags = Set<Tag>()

    fileprivate var metadataQuery: NSMetadataQuery
    fileprivate var currentQueryObjects: [Document]?
    fileprivate let workerQueue: OperationQueue = {
        let workerQueue = OperationQueue()
        workerQueue.name = Bundle.main.bundleIdentifier! + ".browserdatasource.workerQueue"
        workerQueue.maxConcurrentOperationCount = 1
        return workerQueue
    }()
    var delegate: DocumentsQueryDelegate? {
        didSet {
            /*
             If we already have results, we send them to the delegate as an
             initial update.
             */
            if !self.documents.isEmpty {
                OperationQueue.main.addOperation {
                    self.delegate?.documentsQueryResultsDidChangeWithResults(documents: self.documents, tags: self.tags)
                }
            }
        }
    }

    // MARK: - Initialization
    override init() {
        metadataQuery = NSMetadataQuery()

        // Filter only our document type.
        metadataQuery.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "*.pdf")

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
        metadataQuery.operationQueue = workerQueue

        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(DocumentsQuery.queryFeedback(_:)), name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: metadataQuery)
        NotificationCenter.default.addObserver(self, selector: #selector(DocumentsQuery.queryFeedback(_:)), name: NSNotification.Name.NSMetadataQueryDidUpdate, object: metadataQuery)
        metadataQuery.start()
    }

    // MARK: - Notifications
    @objc func queryFeedback(_ notification: Notification) {

        os_log("Got iCloud query feedback from '%@'", log: self.log, type: .debug, notification.name.rawValue)
        self.metadataQuery.disableUpdates()

        self.documents = [Document]()
        self.tags = Set<Tag>()
        for metadataQueryResult in self.metadataQuery.results as? [NSMetadataItem] ?? [] {
            // get the document path
            guard let documentPath = metadataQueryResult.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }

            // Check if it is a local document. These two values are possible for the "NSMetadataUbiquitousItemDownloadingStatusKey":
            // - NSMetadataUbiquitousItemDownloadingStatusCurrent
            // - NSMetadataUbiquitousItemDownloadingStatusNotDownloaded
            guard let downloadingStatus = metadataQueryResult.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String else { continue }

            var documentStatus: DownloadStatus
            switch downloadingStatus {
            case "NSMetadataUbiquitousItemDownloadingStatusCurrent":
                documentStatus = .local
            case "NSMetadataUbiquitousItemDownloadingStatusNotDownloaded":

                if let isDownloading = metadataQueryResult.value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? Bool,
                    isDownloading {
                    documentStatus = .downloading
                } else {
                    documentStatus = .iCloudDrive
                }

            default:
                fatalError()
            }
            self.documents.append(Document(path: documentPath,
                                           downloadStatus: documentStatus,
                                           availableTags: &tags))
        }

        metadataQuery.enableUpdates()

        OperationQueue.main.addOperation {
            self.delegate?.documentsQueryResultsDidChangeWithResults(documents: self.documents, tags: self.tags)
        }
    }
}
