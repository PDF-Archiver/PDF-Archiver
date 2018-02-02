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
    var pdf_date: Date?
    var pdf_description: String? {
        get {
            return self._pdf_description
        }
        set {
            if var raw = newValue {
                // TODO: we could use a CocoaPod here...
                raw = raw.lowercased()
                raw = raw.replacingOccurrences(of: "[:;.,!?/\\^+<>#@|]", with: "", options: .regularExpression, range: nil)
                raw = raw.replacingOccurrences(of: " ", with: "-")
                raw = raw.replacingOccurrences(of: "[-]+", with: "-", options: .regularExpression, range: nil)
                // german umlaute
                raw = raw.replacingOccurrences(of: "ä", with: "ae")
                raw = raw.replacingOccurrences(of: "ö", with: "oe")
                raw = raw.replacingOccurrences(of: "ü", with: "ue")
                raw = raw.replacingOccurrences(of: "ß", with: "ss")

                self._pdf_description = raw
            }
        }
    }
    var pdf_tags: [Tag]?
    fileprivate var _pdf_description: String?

    init(path: URL) {
        self.path = path
        // create a filename and rename the document
        self.name = path.lastPathComponent
    }

    func rename(archive_path: URL) -> Bool {
        // create a filename and rename the document
        if let date = self.pdf_date,
           let description = self.pdf_description,
           let tags = self.pdf_tags {
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
            let new_basepath = archive_path.appendingPathComponent(String(date_str.prefix(4)))
            // check, if this path already exists ... create it
            let new_filepath = new_basepath.appendingPathComponent(filename)

            let fileManager = FileManager.default
            do {
                if !(fileManager.isDirectory(url: new_basepath) ?? false) {
                    try fileManager.createDirectory(at: new_basepath, withIntermediateDirectories: false, attributes: nil)
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
