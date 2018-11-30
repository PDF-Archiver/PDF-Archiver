//
//  Archive.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 22.08.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import Foundation
import os.log

protocol ArchiveDelegate: class {
    func documentChangesOccured(changed changedDocuments: Set<Document>)
}

class Archive {

    weak var delegate: ArchiveDelegate?
    var allDocuments = Set<Document>()
    static var availableTags = Set<Tag>()

    var years: [String] {
        var years = Set<String>()
        for document in allDocuments {
            years.insert(document.folder)
        }
        return Array(years.sorted().reversed().prefix(3))
    }

    func setAllDocuments(_ documents: Set<Document>) {
        allDocuments = documents

        // update the available tags
        Archive.availableTags.removeAll(keepingCapacity: true)
        for document in documents {
            Archive.availableTags.formUnion(document.tags)
        }
    }

    func filterContentForSearchText(_ searchText: String, scope: String = NSLocalizedString("all", comment: "")) -> Set<Document> {

        // slugify searchterms and split them
        let searchTerms: [String] = searchText.lowercased().slugified(withSeparator: " ").split(separator: " ").map { String($0) }

        // filter documents by category
        var categoryFilteredDocuments: Set<Document>
        if scope == NSLocalizedString("all", comment: "") {
            categoryFilteredDocuments = Set(allDocuments)
        } else {
            categoryFilteredDocuments = Set(allDocuments.filter { $0.folder == scope })
        }

        // filter documents by search term
        var filteredDocuments: Set<Document>
        if searchText.isEmpty {
            filteredDocuments = categoryFilteredDocuments
        } else {
            filteredDocuments = categoryFilteredDocuments.intersection(filterBy(searchTerms))
        }

        return filteredDocuments
    }

    static func createDocumentFrom(_ metadataItem: NSMetadataItem) -> Document? {

        // get the document path
        guard let documentPath = metadataItem.value(forAttribute: NSMetadataItemURLKey) as? URL else { return nil }
        let output = Document.parseFilename(documentPath)
        guard output.date != nil,
            output.specification != nil,
            output.tagNames != nil else { return nil }

        // Check if it is a local document. These two values are possible for the "NSMetadataUbiquitousItemDownloadingStatusKey":
        // - NSMetadataUbiquitousItemDownloadingStatusCurrent
        // - NSMetadataUbiquitousItemDownloadingStatusNotDownloaded
        guard let downloadingStatus = metadataItem.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String else { return nil }

        var documentStatus: DownloadStatus
        switch downloadingStatus {
        case "NSMetadataUbiquitousItemDownloadingStatusCurrent":
            documentStatus = .local
        case "NSMetadataUbiquitousItemDownloadingStatusNotDownloaded":

            if let isDownloading = metadataItem.value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? Bool,
                isDownloading {
                let percentDownloaded = Float(truncating: (metadataItem.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? NSNumber) ?? 0)

                documentStatus = .downloading(percentDownloaded: percentDownloaded / 100)
            } else {
                documentStatus = .iCloudDrive
            }
        default:
            fatalError("The downloading status '\(downloadingStatus)' was not handled correctly!")
        }

        // get file size via NSMetadataItemFSSizeKey
        let size = metadataItem.value(forAttribute: NSMetadataItemFSSizeKey) as? Int64

        return Document(path: documentPath, availableTags: &availableTags, size: size ?? 0, downloadStatus: documentStatus)
    }
}

// - MARK: Searcher stubs
extension Archive: Searcher {
    typealias Element = Document
    var allSearchElements: Set<Document> { return Set(allDocuments) }
}

// MARK: - Delegates
extension Archive: DocumentsQueryDelegate {
    func updateWithResults(removedDocuments: Set<Document>, addedDocuments: Set<Document>, changedDocuments: Set<Document>) {
        /*
         Update the set of query objects.
         */
        allDocuments.subtract(removedDocuments)
        allDocuments.formUnion(addedDocuments)

        /*
         KNOWN ISSUE: If a document will be renamed in the iCloud Drive folder, the documents query adds a "changedDocument" with the new filename.
         Since there is no reference to the old document, it can not be removed from "previousQueryObjects".
         */
        for changedResult in changedDocuments {

//            // remove the changed document, e.g. filename has not changed & download status has changed
//            if let documentIndex = allDocuments.firstIndex(where: { $0.filename == changedResult.filename }) {
//                allDocuments.remove(at: documentIndex)
//            }
//
//            // insert the new/changed document to update the download status
//            allDocuments.insert(changedResult)
//            
            allDocuments.update(with: changedResult)
        }

        // show the changes in the archive occured
        delegate?.documentChangesOccured(changed: changedDocuments)
    }
}

// - MARK: helper structs/classes
struct YearSection: Comparable {
    var year: Date
    var headlines: [Document]

    static func < (lhs: YearSection, rhs: YearSection) -> Bool {
        return lhs.year < rhs.year
    }
}
