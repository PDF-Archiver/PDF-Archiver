//
//  Document.swift
//
//
//  Created by Julian Kahnert on 14.03.24.
//

import Foundation
import OSLog
import SwiftData

@Model
final class Document {
    @Attribute(.unique)
    private(set) var id: Int
    var url: URL
    var isTagged: Bool
    var date: Date
    var filename: String
    @Transient
    var size: Measurement<UnitInformationStorage> {
        Measurement(value: _sizeInBytes, unit: .bytes)
    }
    var specification: String

    var tagItems: [Tag]

    @Transient
    var tags: [String] {
        tagItems.map(\.name)
    }

    // the content will be fetched and set on a background thread
    private(set) var content: String

    var _sizeInBytes: Double

    // this property will be set when the object is created and saved to the DB the first time
    // it will be used in the first (full) sync after the app starts
    private(set) var _created: Date

    // 0: remote - 1: local
    var downloadStatus: Double

    init(id: Int, url: URL, isTagged: Bool, filename: String, sizeInBytes: Double, date: Date, specification: String, tags: [Tag], downloadStatus: Double, created: Date) {
        self.id = id
        self.url = url
        self.isTagged = isTagged
        self.date = date
        self.filename = filename
        self.specification = specification
        self.tagItems = tags
        self.content = ""
        self._sizeInBytes = sizeInBytes
        self._created = created
        self.downloadStatus = downloadStatus
    }

    func setContent(_ content: String) {
        self.content = content
    }
}

extension Document {

    static func getBy(id documentId: Int, in modelContext: ModelContext) throws -> Document? {
        let predicate = #Predicate<Document> {
            $0.id == documentId
        }

        var descriptor = FetchDescriptor<Document>(
            predicate: predicate,
            sortBy: [SortDescriptor(\Document.id)]
        )
        descriptor.fetchLimit = 1
        let documents = try modelContext.fetch(descriptor)

        guard let document = documents.first else { return nil }
        if document.downloadStatus < 1 {
            Logger.archiveStore.debug("Start download of document \(document.url.lastPathComponent)")
            let url = document.url
            Task {
                await ArchiveStore.shared.startDownload(of: url)
            }
        }
        return document
    }
}
