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

enum ArchiveError: Error {
    case parsingError
}

extension Archive: DocumentsQueryDelegate {

    func updateWithResults(removedItems: [NSMetadataItem], addedItems: [NSMetadataItem], updatedItems: [NSMetadataItem]) {

        // handle new documents
        for addedItem in addedItems {
            if let output = try? parseMetadataItem(addedItem) {
                self.add(from: output.path, size: output.size, downloadStatus: output.status, status: .tagged)
            }
        }

        let allDocuments = self.get(scope: .all, searchterms: [], status: .tagged)

        // handle removed documents
        let removedDocuments = matchDocumentsFrom(removedItems, availableDocuments: allDocuments)
        self.remove(removedDocuments, status: .tagged)

        // handle updated documents
        var updatedDocuments = Set<Document>()
        for updatedItem in updatedItems {
            if let output = try? parseMetadataItem(updatedItem) {
                let updatedDocument = self.update(from: output.path, size: output.size, downloadStatus: output.status, status: .tagged)
                updatedDocuments.insert(updatedDocument)
            }
        }

        // update documents in view
        self.archiveDelegate?.update(.archivedDocuments(updatedDocuments: updatedDocuments))
    }

    func filterContentForSearchText(_ searchText: String, scope: String = NSLocalizedString("all", comment: "")) -> Set<Document> {

        // slugify searchterms and split them
        let searchTerms: [String] = searchText.lowercased().slugified(withSeparator: " ").split(separator: " ").map { String($0) }

        // add category to search terms
        if scope == NSLocalizedString("all", comment: "") {
            return self.get(scope: .all, searchterms: searchTerms, status: .tagged)
        } else {
            return self.get(scope: .year(year: scope), searchterms: searchTerms, status: .tagged)
        }
    }

    // MARK: - Helper Functions
    private func matchDocumentsFrom(_ metadataItems: [NSMetadataItem], availableDocuments: Set<Document>) -> Set<Document> {

        var documents = Set<Document>()
        for metadataItem in metadataItems {
            if let documentPath = metadataItem.value(forAttribute: NSMetadataItemURLKey) as? URL,
                let foundDocument = availableDocuments.first(where: { $0.path == documentPath }) {
                documents.insert(foundDocument)
            }
        }
        return documents
    }

    private func parseMetadataItem(_ metadataItem: NSMetadataItem) throws -> (path: URL, size: Int64?, status: DownloadStatus) {

        // get the document path
        guard let documentPath = metadataItem.value(forAttribute: NSMetadataItemURLKey) as? URL else { throw ArchiveError.parsingError }
        let output = Document.parseFilename(documentPath)
        guard output.date != nil,
            output.specification != nil,
            output.tagNames != nil else { throw ArchiveError.parsingError }

        // Check if it is a local document. These two values are possible for the "NSMetadataUbiquitousItemDownloadingStatusKey":
        // - NSMetadataUbiquitousItemDownloadingStatusCurrent
        // - NSMetadataUbiquitousItemDownloadingStatusNotDownloaded
        guard let downloadingStatus = metadataItem.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String else { throw ArchiveError.parsingError }

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
        return (documentPath, size, documentStatus)
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
