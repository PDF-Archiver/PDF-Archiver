//
//  Document.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 25.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

class Document: NSObject {
    // structure for PDF documents on disk
    var path: URL
    @objc var name: String?
    @objc var documentDone: String = ""
    var documentDate: Date?
    var documentDescription: String? {
        get {
            return self._documentDescription
        }
        set {
            if var raw = newValue {
                // normalize description
                raw = raw.lowercased()
                raw = raw.replacingOccurrences(of: "[:;.,!?/\\^+<>#@|]", with: "",
                                               options: .regularExpression, range: nil)
                raw = raw.replacingOccurrences(of: " ", with: "-")
                raw = raw.replacingOccurrences(of: "[-]+", with: "-",
                                               options: .regularExpression, range: nil)
                // german umlaute
                raw = raw.replacingOccurrences(of: "ä", with: "ae")
                raw = raw.replacingOccurrences(of: "ö", with: "oe")
                raw = raw.replacingOccurrences(of: "ü", with: "ue")
                raw = raw.replacingOccurrences(of: "ß", with: "ss")

                self._documentDescription = raw
            }
        }
    }
    var documentTags: [Tag]?
    fileprivate var _documentDescription: String?
    fileprivate let _dateFormatter: DateFormatter

    init(path: URL) {
        self.path = path

        // create a filename and rename the document
        self.name = String(path.lastPathComponent)

        // initialize the date formatter
        self._dateFormatter = DateFormatter()
        self._dateFormatter.dateFormat = "yyyy-MM-dd"

        // try to parse the current filename
        // parse the date
        if var dateRaw = regex_matches(for: "^\\d{4}-\\d{2}-\\d{2}--", in: self.name!) {
            self.documentDate = self._dateFormatter.date(from: String(dateRaw[0].dropLast(2)))
        }

        // parse the description
        if var raw = regex_matches(for: "--[a-zA-Z0-9-]+__", in: self.name!) {
            self._documentDescription = getSubstring(raw[0], startIdx: 2, endIdx: -2)
        }

        // parse the tags
        if var raw = regex_matches(for: "__[a-zA-Z0-9_]+.[pdfPDF]{3}$", in: self.name!) {
            let tags = getSubstring(raw[0], startIdx: 2, endIdx: -4).components(separatedBy: "_")
            self.documentTags = [Tag]()
            for tag in tags {
                self.documentTags!.append(Tag(name: tag, count: 0))
            }
        }
    }

    func rename(archivePath: URL) -> Bool {
        // create a filename and rename the document
        if let date = self.documentDate,
           let description = self.documentDescription,
           let tags = self.documentTags {
            if description == "" {
                return false
            }

            // get date
            let date_str = self._dateFormatter.string(from: date)

            // get tags
            var tag_str = ""
            for tag in tags.sorted(by: { $0.name < $1.name }) {
                tag_str += "\(tag.name)_"
            }
            tag_str = String(tag_str.dropLast(1))

            // create new filepath
            let filename = "\(date_str)--\(description)__\(tag_str).pdf"
            let new_basepath = archivePath.appendingPathComponent(String(date_str.prefix(4)))
            // check, if this path already exists ... create it
            let new_filepath = new_basepath.appendingPathComponent(filename)

            let fileManager = FileManager.default
            do {
                if !(fileManager.isDirectory(url: new_basepath) ?? false) {
                    try fileManager.createDirectory(at: new_basepath,
                                                    withIntermediateDirectories: false, attributes: nil)
                }

                try fileManager.moveItem(at: self.path, to: new_filepath)
            } catch let error as NSError {
                print("Ooops! Something went wrong: \(error)")
                return false
            }
            self.name = String(new_filepath.lastPathComponent)
            self.path = new_filepath
            self.documentDone = "✔️"
            
            do {
                var tags = [String]()
                for tag in self.documentTags ?? [] {
                    tags += [tag.name]
                }
                
                // set file tags [https://stackoverflow.com/a/47340666]
                try (new_filepath as NSURL).setResourceValue(tags, forKey: URLResourceKey.tagNamesKey)
            } catch let error as NSError {
                print("Could not set file tags: \(error)")
            }
            return true

        } else {
            dialogOK(message_key: "renaming_failed", info_key: "check_document_fields", style: .warning)
            return false
        }
    }
}
