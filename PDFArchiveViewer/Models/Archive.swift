//
//  Archive.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 22.08.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Dwifft
import Foundation
import os.log

struct Archive {

    private var allDocuments = [Document]()
    static var availableTags = Set<Tag>()

    var years: [String] {
        var years = Set<String>()
        for document in allDocuments {
            years.insert(document.folder)
        }
        return Array(years.sorted().reversed().prefix(3))
    }

    mutating func setAllDocuments(_ documents: [Document]) {
        allDocuments = documents

        // update the available tags
        Archive.availableTags.removeAll(keepingCapacity: true)
        for document in documents {
            Archive.availableTags.formUnion(document.tags)
        }
    }

    func filterContentForSearchText(_ searchText: String, scope: String = NSLocalizedString("all", comment: "")) -> SectionedValues<String, Document> {

        // slugify searchterms and split them
        let searchTerms: [String] = searchText.lowercased().slugify(withSeparator: " ").split(separator: " ").map { String($0) }

        // create a set of tags for each searchterm
        let searchedTagsMap = searchTerms.reduce(into: [String: Set<Tag>]()) {(result, searchTerm) in
            result[searchTerm] = Archive.availableTags.filter { return $0.name.lowercased().hasPrefix(searchTerm) }
        }

        // filter documents
        let filteredDocuments = allDocuments.filter {( document: Document) -> Bool in
            let doesCategoryMatch = (scope == NSLocalizedString("all", comment: "")) || (document.folder == scope)

            if searchText.isEmpty {
                return doesCategoryMatch
            } else {

                // TODO: maybe also search in date
                let foundPerSearchterm = searchTerms.reduce(into: true) { (result, searchTerm) in
                    let foundInSpecification = document.specification.lowercased().contains(searchTerm)
                    let foundInTags = !document.tags.isDisjoint(with: searchedTagsMap[searchTerm] ?? [])
                    result = result && (foundInSpecification || foundInTags)
                }

                return doesCategoryMatch && foundPerSearchterm
            }
        }

        // create table sections
        return SectionedValues(values: filteredDocuments,
                               valueToSection: { (document) in
                                let calender = Calendar.current
                                return String(calender.component(.year, from: document.date)) },
                               sortSections: { return $0 > $1 },
                               sortValues: { return $0 > $1 })
    }

    static func createDocumentFrom(_ metadataItem: NSMetadataItem) -> Document? {

        // get the document path
        guard let documentPath = metadataItem.value(forAttribute: NSMetadataItemURLKey) as? URL,
            Document.parseFilename(documentPath.lastPathComponent) != nil else { return nil }

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

                documentStatus = .downloading(percentDownloaded: percentDownloaded)
            } else {
                documentStatus = .iCloudDrive
            }
        default:
            fatalError("The downloading status '\(downloadingStatus)' was not handled correctly!")
        }

        return Document(path: documentPath, downloadStatus: documentStatus, availableTags: &availableTags)
    }
}

struct YearSection: Comparable {
    static func < (lhs: YearSection, rhs: YearSection) -> Bool {
        return lhs.year < rhs.year
    }

    var year: Date
    var headlines: [Document]

}
