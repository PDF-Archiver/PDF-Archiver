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
    var documentDate: Date?
    var documentDescription: String? {
        get {
            return self._documentDescription
        }
        set {
            if var raw = newValue {
                // TODO: we could use a CocoaPod here...
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

    init(path: URL) {
        self.path = path
        // create a filename and rename the document
        self.name = path.lastPathComponent
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
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let date_str = formatter.string(from: date)

            // get tags
            var tag_str = ""
            for tag in tags {
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
            return true

        } else {
            print("Renaming not possible! Doublecheck the document fields.")
            return false
        }
    }
}
