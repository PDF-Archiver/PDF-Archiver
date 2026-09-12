//
//  FilenameGenerator.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.26.
//

import ArchiverModels
import Foundation

enum FilenameGenerator {

    /// Reuse the original filename when it already follows the naming scheme
    /// (parseable date + real specification); otherwise generate a placeholder
    /// name carrying the import date.
    ///
    /// The placeholder specification/tag mark the document as untagged for
    /// `ArchiveStore.isTagged` until the user tags it.
    static func filename(reusing originalFilename: String?) async -> String {
        if let originalFilename {
            let parsedOutput = await Document.parseFilename(originalFilename)
            if parsedOutput.date != nil,
               let specification = parsedOutput.specification,
               specification != Document.descriptionPlaceholder {
                // the current filename of the document could be parsed and has no placeholders, so we use it
                return originalFilename
            }
        }

        let specification = Document.descriptionPlaceholder + Date().timeIntervalSince1970.description
        return Document.createFilename(date: Date(), specification: specification, tags: Set([Document.tagPlaceholder]))
    }
}
