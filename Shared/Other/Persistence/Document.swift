//
//  Document.swift
//
//
//  Created by Julian Kahnert on 14.03.24.
//

import Foundation
import SwiftData

@Model
final class Document {
    private(set) var id: String = ""
    var url: URL = URL(filePath: "")
    var isTagged = false
    var date = Date()
    var filename: String = ""
    @Transient
    var size: Measurement<UnitInformationStorage> {
        Measurement(value: _sizeInBytes, unit: .bytes)
    }
    var specification: String = ""
    @Relationship(inverse: \Tag.documents) var tagItems: [Tag]

    @Transient
    var tags: [String] {
        tagItems.map(\.name)
    }
    var content: String = ""

    var _sizeInBytes: Double

    // 0: remote - 1: local
    var downloadStatus: Double

    init(id: String, url: URL, isTagged: Bool, filename: String, sizeInBytes: Double, date: Date, specification: String, tags: [Tag], content: String, downloadStatus: Double) {
        self.id = id
        self.url = url
        self.isTagged = isTagged
        self.filename = filename
        self._sizeInBytes = sizeInBytes
        self.date = date
        self.specification = specification
        self.tagItems = tags
        self.content = content
        self.downloadStatus = downloadStatus
    }
}

extension Document {
    enum DownloadStatus: Equatable, Codable {
        case remote
        case downloading(percent: Double)
        case local
    }
}
