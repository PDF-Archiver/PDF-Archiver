//
//  Document.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 30.06.25.
//

import Foundation

public struct Document: Equatable, Identifiable {
    public var id: URL { url }
    public var url: URL
    public var date: Date
    public var specification: String
    public var tags: Set<String>
    
    // 0: remote - 1: local
    public var downloadStatus: Double
    
    public var filename: String {
        url.lastPathComponent
    }
    
    public init(url: URL, date: Date, specification: String, tags: Set<String>, downloadStatus: Double) {
        self.url = url
        self.date = date
        self.specification = specification
        self.tags = tags
        self.downloadStatus = downloadStatus
    }
}

#if DEBUG
extension Document {
    public static func mock(url: URL = URL(string: "https://example.com")!, date: Date = Date(), specification: String = "", tags: Set<String> = [], downloadStatus: Double = 0) -> Self {
        .init(
            url: url,
            date: date,
            specification: specification,
            tags: tags,
            downloadStatus: downloadStatus
        )
    }
}
#endif
