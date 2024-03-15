//
//  DBDocument.swift
//
//
//  Created by Julian Kahnert on 14.03.24.
//

import Foundation
import SwiftData

@Model
public final class DBDocument {
    public private(set) var id: String = ""
    public var date = Date()
    public var specification: String = ""
    public var tags: [String] = []

    // 0: remote - 1: local
    public var downloadStatus: Double

    init(id: String, date: Date = Date(), specification: String = "", tags: [String] = [], downloadStatus: Double = 0) {
        self.id = id
        self.date = date
        self.specification = specification
        self.tags = tags
        self.downloadStatus = downloadStatus
    }
}

extension DBDocument {
    public enum DownloadStatus: Equatable, Codable {
        case remote
        case downloading(percent: Double)
        case local
    }
}
