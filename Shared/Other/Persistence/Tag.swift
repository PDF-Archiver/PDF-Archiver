//
//  Tag.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 03.10.24.
//

import SwiftData

@Model
final class Tag {
    @Attribute(.unique) var name: String
    @Relationship(deleteRule: .nullify) private(set) var documents: [Document]
    
    init(name: String, documents: [Document]) {
        self.name = name
        self.documents = documents
    }
}
