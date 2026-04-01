//
//  DocumentEntity.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 19.03.26.
//

import AppIntents
import ArchiverModels
import CoreSpotlight
import Shared

/// An archived PDF document exposed to the system as an App Entity,
/// enabling Shortcuts automations, Spotlight search, and Siri integration.
public struct DocumentEntity: AppEntity {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: LocalizedStringResource("Document"))
    }

    public static let defaultQuery = DocumentEntityQuery()

    public var id: Document.ID
    var url: URL
    public var date: Date
    public var specification: String
    public var tags: Set<String>
    public var isTagged: Bool

    public var displayRepresentation: DisplayRepresentation {
        let title = specification.isEmpty ? url.lastPathComponent : specification
        let tagsString = tags.sorted().map { "#\($0)" }.joined(separator: " ")
        let subtitle: LocalizedStringResource? = tagsString.isEmpty ? nil : "\(tagsString)"
        return DisplayRepresentation(title: "\(title)", subtitle: subtitle)
    }

    public init(id: Document.ID, url: URL, date: Date, specification: String, tags: Set<String>, isTagged: Bool) {
        self.id = id
        self.url = url
        self.date = date
        self.specification = specification
        self.tags = tags
        self.isTagged = isTagged
    }

    public init(document: Document) {
        self.id = document.id
        self.url = document.url
        self.date = document.date
        self.specification = document.specification
        self.tags = document.tags
        self.isTagged = document.isTagged
    }
}

extension DocumentEntity: IndexedEntity {
    public var attributeSet: CSSearchableItemAttributeSet {
        Document(
            id: id, url: url, date: date, specification: specification,
            tags: tags, isTagged: isTagged, sizeInBytes: 0, downloadStatus: 0
        ).searchableAttributes
    }
}
