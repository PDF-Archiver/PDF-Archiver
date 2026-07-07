//
//  Document.swift
//  ArchiveLib
//
//  Created by Julian Kahnert on 13.11.18.
//

import Foundation
#if os(OSX)
import Quartz.PDFKit
#else
import PDFKit
#endif
import ArchiverModels
import OSLog

extension Document {

    /// Parse the filename from an URL.
    ///
    /// - Parameter path: Path which should be parsed.
    /// - Returns: Date, specification and tag names which can be parsed from the path.
    @concurrent
    public static func parseFilename(_ filename: String) async -> (date: Date?, specification: String?, tagNames: [String]?) {

        // try to parse the current filename
        var date: Date?
        if let parsed = Self.getFilenameDate(filename) {
            date = parsed
        } else if let parsedDate = await DateParser.parse(filename).first {
            date = parsedDate
        }

        // parse the specification
        var specification: String?

        let components = filename.components(separatedBy: "--")
        if components.count == 2,
           let lastComponents = components.last?.components(separatedBy: "__"),
           lastComponents.count == 2,
           let raw = lastComponents.first,
           !raw.isEmpty {

            // try to parse the real specification from scheme
            specification = raw
        }

        // parse the tags
        var tagNames: [String]?
        let separator = "__"
        if filename.contains(separator),
           let raw = filename.components(separatedBy: separator).last?.dropLast(filename.hasSuffix(".pdf") ? 4 : 0),
           !raw.isEmpty {
            // parse the tags of a document
            tagNames = raw.lowercased()
                .components(separatedBy: "_")
                .flatMap { $0.components(separatedBy: .whitespacesAndNewlines) }
        }

        if let foundSpecification = specification,
           foundSpecification.lowercased().starts(with: Constants.documentDescriptionPlaceholder.lowercased()) {
            specification = nil
        }
        if let foundTagNames = tagNames,
            foundTagNames.contains(where: { $0.lowercased() == Constants.documentTagPlaceholder.lowercased() }) {
            tagNames = nil
        }

        return (date, specification, tagNames)
    }

    nonisolated private static func getFilenameDate(_ filename: String) -> Date? {
        var rawDate: String?

        let dashComponents = filename.components(separatedBy: "--")
        let underscoreComponents = filename.components(separatedBy: "__")
        if dashComponents.count > 1 {
            rawDate = dashComponents.first
        } else if underscoreComponents.count > 1 {
            rawDate = underscoreComponents.first
        }

        guard let rawDate else { return nil }
        return DateFormatter.yyyyMMdd.date(from: rawDate)
    }
}
