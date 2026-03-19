//
//  Document+Spotlight.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 19.03.26.
//

import ArchiverModels
import CoreSpotlight
import UniformTypeIdentifiers

extension Document {
    /// Builds the `CSSearchableItemAttributeSet` used for Spotlight indexing.
    /// Shared between `SpotlightStoreDependency` (SPM) and `DocumentEntity` (app target).
    public var searchableAttributes: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: UTType.pdf)
        attributes.title = specification.isEmpty ? url.lastPathComponent : specification
        attributes.contentModificationDate = date
        attributes.keywords = tags.sorted()
        attributes.identifier = "\(id)"
        return attributes
    }
}
