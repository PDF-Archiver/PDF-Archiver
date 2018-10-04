//
//  Document.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 22.08.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation
import os.log

enum DownloadStatus: Equatable {
    case iCloudDrive
    case downloading(percentDownloaded: Float)
    case local
}

struct Document: Logging {

    // data from filename
    private(set) var date: Date
    private(set) var specification: String
    private(set) var specificationCapitalized: String
    private(set) var tags = Set<Tag>()

    private(set) var folder: String
    private(set) var downloadStatus: DownloadStatus

    private(set) var filename: String
    private(set) var path: URL

    init(path documentPath: URL, downloadStatus documentDownloadStatus: DownloadStatus, availableTags: inout Set<Tag>) {

        downloadStatus = documentDownloadStatus
        path = documentPath
        filename = documentPath.lastPathComponent
        folder = documentPath.deletingLastPathComponent().lastPathComponent

        guard let parts = filename.capturedGroups(withRegex: "(\\d{4}-\\d{2}-\\d{2})--(.+)__([\\w\\d_]+)\\.[pdfPDF]{3}$") else { fatalError("Could not parse document filename!") }

        // parse the document date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let documentDate = dateFormatter.date(from: parts[0]) else { fatalError("Could not parse the document date!") }
        date = documentDate

        // parse the document specification
        specification = parts[1]
        specificationCapitalized = specification
            .split(separator: "-")
            .map { String($0).capitalizingFirstLetter() }
            .joined(separator: " ")

        // parse the document tags
        for tagname in parts[2].split(separator: "_") {

            if var availableTag = availableTags.first(where: { $0.name == String(tagname) }) {
                availableTag.count += 1
                tags.insert(availableTag)
            } else {
                let newTag = Tag(name: String(tagname), count: 1)
                availableTags.insert(newTag)
                tags.insert(newTag)
            }
        }
    }

    mutating func download() {
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: path)
            downloadStatus = .downloading(percentDownloaded: 0)
        } catch {
            os_log("%s", log: log, type: .debug, error.localizedDescription)
        }
    }
}

extension Document: Hashable, Comparable, CustomStringConvertible {
    static func < (lhs: Document, rhs: Document) -> Bool {
        return lhs.date < rhs.date
    }
    static func == (lhs: Document, rhs: Document) -> Bool {
        return lhs.path == rhs.path
    }
    var description: String { return filename }
    var hashValue: Int { return path.hashValue }
}
