//
//  Archive.swift
//  PDFArchiver
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

    func updateWithResults(removedItems: [NSMetadataItem], addedItems: [NSMetadataItem], updatedItems: [NSMetadataItem]) -> Set<Document> {

        // get trashed files and remove from tmpUpdatedItems
        var tmpUpdatedItems = updatedItems
        var tmpRemovedItems = removedItems
        for updatedItem in updatedItems {
            guard let path = updatedItem.value(forAttribute: NSMetadataItemPathKey) as? String else { continue }
            if path.contains("/.Trash/") {

                tmpRemovedItems.append(updatedItem)
                guard let index = tmpUpdatedItems.firstIndex(of: updatedItem) else { continue }
                tmpUpdatedItems.remove(at: index)
            }
        }

        // handle new documents
        for addedItem in addedItems {
            if let output = try? parseMetadataItem(addedItem) {

                // set tagging status of this document
                let status = Archive.getTaggingStatus(of: output.path)

                // add document to archive
                add(from: output.path, size: output.size, downloadStatus: output.status, status: status)
            }
        }

        // get first 10 untagged documents
        let untaggedDocuments = get(scope: .all, searchterms: [], status: .untagged)
        for document in Array(untaggedDocuments).sorted().reversed().prefix(10) where document.downloadStatus == .iCloudDrive {
            document.download()
        }

        // handle removed documents
        let taggedDocuments = get(scope: .all, searchterms: [], status: .tagged)
        let removedDocuments = matchDocumentsFrom(tmpRemovedItems, availableDocuments: taggedDocuments.union(untaggedDocuments))
        remove(removedDocuments)

        // handle updated documents
        var updatedDocuments = Set<Document>()
        for tmpUpdatedItem in tmpUpdatedItems {
            if let output = try? parseMetadataItem(tmpUpdatedItem) {
                let status = Archive.getTaggingStatus(of: output.path)
                let updatedDocument = update(from: output.path, size: output.size, downloadStatus: output.status, status: status)
                updatedDocuments.insert(updatedDocument)
            }
        }
        return updatedDocuments
    }

    func filterContentForSearchText(_ searchText: String, scope: String = NSLocalizedString("all", comment: "")) -> Set<Document> {

        // slugify searchterms and split them
        let searchTerms: [String] = searchText.lowercased().slugified(withSeparator: " ").split(separator: " ").map { String($0) }

        // add category to search terms
        if scope == NSLocalizedString("all", comment: "") {
            return get(scope: .all, searchterms: searchTerms, status: .tagged)
        } else {
            return get(scope: .year(year: scope), searchterms: searchTerms, status: .tagged)
        }
    }

    // MARK: - Helper Functions

    private static func getTaggingStatus(of url: URL) -> TaggingStatus {
        let regex = "^(\\d{4}-\\d{2}-\\d{2}--[^_]+__[\\w\\d_]+.[pdfPDF]{3})$"

        guard !url.deletingLastPathComponent().lastPathComponent.contains(StorageHelper.Paths.untaggedFolderName),
            let groups = url.lastPathComponent.capturedGroups(withRegex: regex),
            !groups.isEmpty else { return .untagged }

        return .tagged
    }

    private func matchDocumentsFrom(_ metadataItems: [NSMetadataItem], availableDocuments: Set<Document>) -> Set<Document> {

        var documents = Set<Document>()
        for metadataItem in metadataItems {
            if let documentPath = metadataItem.value(forAttribute: NSMetadataItemURLKey) as? URL,
                let foundDocument = availableDocuments.first(where: { $0.path.lastPathComponent == documentPath.lastPathComponent }) {
                documents.insert(foundDocument)
            }
        }
        return documents
    }

    private func parseMetadataItem(_ metadataItem: NSMetadataItem) throws -> (path: URL, size: Int64?, status: DownloadStatus) {

        // get the document path
        guard let documentPath = metadataItem.value(forAttribute: NSMetadataItemURLKey) as? URL else { throw ArchiveError.parsingError }

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
            Log.send(.error, "Unkown download status.", extra: ["status": downloadingStatus])
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
