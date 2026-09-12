//
//  ArchiveStyle.swift
//  ArchiverLib
//

import ArchiverModels
import Foundation

/// The house style of an archive: how its descriptions are shaped, and the
/// phrases a suggestion must never contain.
public enum ArchiveStyle {

    /// Turn a model description into the string that would end up in the
    /// filename, so it can be compared against a filed specification.
    ///
    /// Mirrors what `DocumentInformationForm` does when the user saves.
    public static func specification(fromDescription description: String) -> String {
        description.slugified(withSeparator: "-").lowercased()
    }

    /// Fragments that mark the model describing the *text* instead of the
    /// document - the failure the extraction instructions explicitly forbid.
    public static let metaCommentaryFragments = [
        "unlesbar",
        "nicht-lesbar",
        "dokumententext",
        "dokumenteninhalt",
        "kein-inhalt",
        "keine-informationen",
        "unreadable",
        "garbled",
        "no-content",
        "not-readable",
        "document-text"
    ]

    /// Whether the description talks about the document text rather than the
    /// document. Checked on the slugified form so word separators are uniform.
    public static func containsMetaCommentary(_ description: String) -> Bool {
        let slug = specification(fromDescription: description)
        return metaCommentaryFragments.contains { slug.contains($0) }
    }
}
