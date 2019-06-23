//
//  WKTagsField.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.04.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation
import WSTagsField

extension WSTagsField {

    func contains(_ name: String) -> Bool {
        return tags.contains { $0.text.lowercased() == name.lowercased() }
    }

    func sortTags() {
        var tags = self.tags
        tags.sort { $0.text < $1.text }

        self.removeTags()
        self.addTags(tags)
    }
}
