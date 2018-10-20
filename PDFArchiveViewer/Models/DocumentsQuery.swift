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

import os.log
import UIKit

/**
 The delegate protocol implemented by the object that receives our results. We
 pass the updated list of results as well as a set of animations.
 */
protocol DocumentsQueryDelegate: class {
    func documentsQueryResultsDidChangeWithResults(documents: [Document])
}

/**
 The DocumentBrowserQuery wraps an `NSMetadataQuery` to insulate us from the
 queueing and animation concerns. It runs the query and computes animations
 from the results set.
 */
class DocumentsQuery: NSObject, Logging {

    private var metadataQuery: NSMetadataQuery
    private var queryObjects = Set<Document>()

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

        let changedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem]
        let removedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem]
        let addedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem]

        let changedResults = buildModelObjectSet(objects: changedMetadataItems ?? [])
        let removedResults = buildModelObjectSet(objects: removedMetadataItems ?? [])
        let addedResults = buildModelObjectSet(objects: addedMetadataItems ?? [])

        updateWithResults(removedDocuments: removedResults, addedDocuments: addedResults, changedDocuments: changedResults)
    }

    @objc
    func finishGathering(notification: NSNotification) {

        os_log("Documents query finished.", log: log, type: .debug)
        guard let metadataQueryResults = metadataQuery.results as? [NSMetadataItem] else { return }

        metadataQuery.disableUpdates()
        let results = buildModelObjectSet(objects: metadataQueryResults)
        metadataQuery.enableUpdates()

        updateWithResults(removedDocuments: Set<Document>(), addedDocuments: results, changedDocuments: Set<Document>())
    }

    // MARK: - Result handling/animations

    private func buildModelObjectSet(objects: [NSMetadataItem]) -> Set<Document> {
        // Create an ordered set of model objects.
        let array = objects.compactMap { Archive.createDocumentFrom($0) }

        return Set(array)
    }

    private func buildQueryResultSet() -> Set<Document> {
        /*
         Create an ordered set of model objects from the query's current
         result set.
         */
        metadataQuery.disableUpdates()

        guard let metadataQueryResults = metadataQuery.results as? [NSMetadataItem] else { fatalError("No metadata query results found.") }
        let results = buildModelObjectSet(objects: metadataQueryResults)

        metadataQuery.enableUpdates()
        return results
    }

    private func updateWithResults(removedDocuments: Set<Document>, addedDocuments: Set<Document>, changedDocuments: Set<Document>) {
        /*
         Update the set of query objects.
         */
        queryObjects.subtract(removedDocuments)
        queryObjects.formUnion(addedDocuments)

        /*
         KNOWN ISSUE: If a document will be renamed in the iCloud Drive folder, the documents query adds a "changedDocument" with the new filename.
         Since there is no reference to the old document, it can not be removed from "previousQueryObjects".
         */
        for changedResult in changedDocuments {

            // remove the changed document, e.g. filename has not changed & download status has changed
            if let documentIndex = queryObjects.firstIndex(where: { $0.filename == changedResult.filename }) {
                queryObjects.remove(at: documentIndex)
            }

            // insert the new/changed document to update the download status
            queryObjects.insert(changedResult)
        }

        OperationQueue.main.addOperation {
            self.delegate?.documentsQueryResultsDidChangeWithResults(documents: Array(self.queryObjects))
        }
    }
}
