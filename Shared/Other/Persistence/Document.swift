//
//  Document.swift
//
//
//  Created by Julian Kahnert on 14.03.24.
//

import Foundation
import SwiftData
import OSLog

@Model
final class Document {
    @Attribute(.unique)
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

    // this property will be set when the object is created and saved to the DB the first time
    // it will be used in the first (full) sync after the app starts
    private(set) var _created = Date()

    // 0: remote - 1: local
    var downloadStatus: Double

    init(id: String, url: URL, isTagged: Bool, filename: String, sizeInBytes: Double, date: Date, specification: String, tags: [Tag], content: String, downloadStatus: Double, created: Date) {
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
        self._created = created
    }
}

extension Document {

    static func getBy(id documentId: String, in modelContext: ModelContext) async throws -> Document? {
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
            await ArchiveStore.shared.startDownload(of: document.url)
        }
        return document
    }
}
