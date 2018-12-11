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

import ArchiveLib
import os.log
import UIKit

/**
 The delegate protocol implemented by the object that receives our results. We
 pass the updated list of results as well as a set of animations.
 */
protocol DocumentsQueryDelegate: class {
    func updateWithResults(removedItems: [NSMetadataItem], addedItems: [NSMetadataItem], updatedItems: [NSMetadataItem])
}

/**
 The DocumentBrowserQuery wraps an `NSMetadataQuery` to insulate us from the
 queueing and animation concerns. It runs the query and computes animations
 from the results set.
 */
class DocumentsQuery: NSObject, Logging {

    private var metadataQuery: NSMetadataQuery

    private let workerQueue: OperationQueue = {
        let workerQueue = OperationQueue()

        workerQueue.name = (Bundle.main.bundleIdentifier ?? "PDFArchiveViewer") + ".browserdatasource.workerQueue"
        workerQueue.maxConcurrentOperationCount = 1

        return workerQueue
    }()

    weak var delegate: DocumentsQueryDelegate?

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

        NotificationCenter.default.addObserver(self, selector: #selector(DocumentsQuery.finishGathering(notification:)), name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: metadataQuery)
        NotificationCenter.default.addObserver(self, selector: #selector(DocumentsQuery.queryUpdated(notification:)), name: NSNotification.Name.NSMetadataQueryDidUpdate, object: metadataQuery)

        metadataQuery.start()
        os_log("Starting the documents query.", log: log, type: .debug)
    }

    // MARK: - Notifications

    @objc
    func queryUpdated(notification: NSNotification) {

        os_log("Documents query update.", log: log, type: .debug)

        let changedMetadataItems = (notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem]) ?? []
        let removedMetadataItems = (notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem]) ?? []
        let addedMetadataItems = (notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem]) ?? []

        // update the archive
        self.delegate?.updateWithResults(removedItems: removedMetadataItems, addedItems: addedMetadataItems, updatedItems: changedMetadataItems)
    }

    @objc
    func finishGathering(notification: NSNotification) {

        os_log("Documents query finished.", log: log, type: .debug)
        guard let metadataQueryResults = metadataQuery.results as? [NSMetadataItem] else { return }

        // update the archive
        self.delegate?.updateWithResults(removedItems: [], addedItems: metadataQueryResults, updatedItems: [])
    }
}
