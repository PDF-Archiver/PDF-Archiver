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
    public static func parseFilename(_ filename: String) -> (date: Date?, specification: String?, tagNames: [String]?) {

        // try to parse the current filename
        var date: Date?
        // var rawDate = ""
        if let parsed = Document.getFilenameDate(filename) {
            date = parsed.date
            // rawDate = parsed.rawDate
        } else if let parsedDate = DateParser.parse(filename).first {
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

//        } else {
//
//            // save a first "raw" specification
//            let tempSepcification = filename.lowercased()
//                // drop the already parsed date
//                .dropFirst(rawDate.count)
//                // drop the extension and the last .
//                .dropLast(filename.hasSuffix(".pdf") ? 4 : 0)
//                // exclude tags, if they exist
//                .components(separatedBy: "__")[0]
//                // clean up all "_" - they are for tag use only!
//                .replacingOccurrences(of: "_", with: "-")
//                // remove a pre or suffix from the string
//                .trimmingCharacters(in: ["-", " "])
//
//            // save the raw specification, if it is not empty
//            if !tempSepcification.isEmpty {
//                specification = tempSepcification
//            }
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

    private static func getFilenameDate(_ filename: String) -> (date: Date, rawDate: String)? {
        var rawDate: String?
        if let components = filename.components(separatedBy: "--") as [String]?, components.count > 1 {
            rawDate = components.first
        } else if let components = filename.components(separatedBy: "__") as [String]?, components.count > 1 {
            rawDate = components.first
        }

        guard let rawDate,
              let date = DateFormatter.yyyyMMdd.date(from: rawDate) else { return nil }
        return (date, rawDate)
    }

    public static func createFilename(date: Date, specification: String, tags: Set<String>) -> String {
        // get formatted date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: date)

        // get description

        // get tags
        var tagStr = ""
        for tag in tags.sorted() {
            tagStr += "\(tag)_"
        }
        tagStr = String(tagStr.dropLast(1))

        // create new file path
        return "\(dateStr)--\(specification)__\(tagStr).pdf"
    }
}
