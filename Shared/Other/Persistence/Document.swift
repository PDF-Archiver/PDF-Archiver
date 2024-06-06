//
//  Document.swift
//
//
//  Created by Julian Kahnert on 14.03.24.
//

import Foundation
import SwiftData

@Model
public final class Document  {
    public private(set) var id: String = ""
    public var url: URL = URL(filePath: "")
    public var isTagged = false
    public var date = Date()
    public var filename: String = ""
    public var specification: String = ""
    public var tags: [String] = []

    // 0: remote - 1: local
    public var downloadStatus: Double

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
    public enum DownloadStatus: Equatable, Codable {
        case remote
        case downloading(percent: Double)
        case local
    }
}
