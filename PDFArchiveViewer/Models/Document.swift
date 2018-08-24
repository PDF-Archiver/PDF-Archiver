//
//  Document.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 22.08.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

class Document {

    // data from filename
    private(set) var date: Date
    private(set) var specification: String
    private(set) var tags = Set<Tag>()

    private(set) var folder: String
    private(set) var isLocal: Bool

    private(set) var filename: String
    private(set) var path: URL

    init(path documentPath: URL, isLocal: Bool, availableTags: inout Set<Tag>) {

        self.isLocal = isLocal
        self.path = documentPath
        self.filename = documentPath.lastPathComponent
        self.folder = documentPath.deletingLastPathComponent().lastPathComponent

        let parts = self.filename.capturedGroups(withRegex: "(\\d{4}-\\d{2}-\\d{2})--(.+)__([\\w\\d_]+)\\.[pdfPDF]{3}$")!

        // parse the document date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        self.date = dateFormatter.date(from: parts[0])!

        // parse the document specification
        self.specification = parts[1]

        // parse the document tags
        for tagname in parts[2].split(separator: "_") {

            if let availableTag = availableTags.filter({$0.name == String(tagname)}).first {
                availableTag.count += 1
                self.tags.insert(availableTag)
            } else {
                let newTag = Tag(name: String(tagname), count: 1)
                availableTags.insert(newTag)
                self.tags.insert(newTag)
            }
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
    var description: String { return self.filename }
    var hashValue: Int { return self.path.hashValue }
}
