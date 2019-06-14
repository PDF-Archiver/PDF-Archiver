//
//  Document.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 14.06.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import Foundation

extension Document {

    func cleaned() -> Document {
        // cleanup the found document
        if let tag = tags.first(where: { $0.name == Constants.documentTagPlaceholder }) {
            tags.remove(tag)
        }
        if specification.contains(Constants.documentDescriptionPlaceholder) {
            specification = ""
        }

        return self
    }
}
