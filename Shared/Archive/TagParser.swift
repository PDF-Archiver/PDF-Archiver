//
//  TagParser.swift
//  ArchiveLib
//
//  Created by Julian Kahnert on 28.12.18.
//
// Example from: https://developer.apple.com/documentation/naturallanguage/identifying_people_places_and_organizations

import Foundation
import NaturalLanguage

/// Parse tags from a String.
enum TagParser {

    private static let seperator = "-"

    /// Get tag names from a string.
    ///
    /// - Parameter raw: Raw string which might contain some tags.
    /// - Returns: Found tag names.
    static func parse(_ text: String) -> Set<String> {
        var documentTags = Set<String>()

        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther, .joinContractions]

        let tags: [NLTag] = [.personalName, .organizationName, .placeName]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if let tag = tag,
                tags.contains(tag) {

                // slugify tag
                let foundTagName = String(text[tokenRange]).lowercased().slugified(withSeparator: seperator)

                // validate the found tag:
                // * should not contain any sperators, since this is a hint on duplicates, e.g. "zalando" vs. "zalando se"
                // * should have more than 2 characters
                if !foundTagName.contains(seperator) && foundTagName.count > 2 {
                    documentTags.insert(foundTagName)
                }
            }
            return true
        }

        return documentTags
    }
}
