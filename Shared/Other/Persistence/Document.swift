//
//  Document.swift
//
//
//  Created by Julian Kahnert on 14.03.24.
//

import Foundation
import SwiftData

@Model
final class Document  {
    private(set) var id: String = ""
    var url: URL = URL(filePath: "")
    var isTagged = false
    var date = Date()
    var filename: String = ""
    var specification: String = ""
    var tags: [String] = []

    // 0: remote - 1: local
    var downloadStatus: Double

    init(id: String, url: URL, isTagged: Bool, filename: String, date: Date, specification: String, tags: [String], downloadStatus: Double) {
        self.id = id
        self.url = url
        self.isTagged = isTagged
        self.filename = filename
        self.date = date
        self.specification = specification
        self.tags = tags
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
