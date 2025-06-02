//
//  Tag.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 03.10.24.
//

import SwiftData
import SwiftUI

@Model
final class Tag {
    @Attribute(.unique)
    var name: String

    @Relationship(inverse: \Document.tagItems)
    private(set) var documents: [Document]

    init(name: String, documents: [Document]) {
        self.name = name
        self.documents = documents
    }

    static func getOrCreate(name: String, in context: ModelContext) -> Tag {
        let predicate = #Predicate<Tag> { tag in
            return tag.name == name
        }

        var descriptor = FetchDescriptor<Tag>(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            let results = try context.fetch(descriptor)
            if let foundTag = results.first {
                return foundTag
            } else {
                return Tag(name: name, documents: [])
            }
        } catch {
            assertionFailure("Failed to fetch tag: \(error.localizedDescription).")
            return Tag(name: name, documents: [])
        }
    }
}
