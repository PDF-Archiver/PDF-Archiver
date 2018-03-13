//
//  Document.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 25.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation
import os.log

//protocol PreferencesDelegate: class {
//    func setTagList(tagDict: [String: Int])
//    func getTagList() -> [String: Int]
//}

class Document: NSObject {
    let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Document")
    weak var delegate: TagsDelegate?
    // structure for PDF documents on disk
    var path: URL
    @objc var name: String?
    @objc var documentDone: String = ""
    var documentDate = Date()
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
                
                // trailing previous whitespaces from beginning/end
                if raw.hasSuffix("-") {
                    raw = String(raw.dropLast())
                }
                if raw.hasPrefix("-") {
                    raw = String(raw.dropFirst())
                }

                self._documentDescription = raw
            }
        }
    }
    var documentTags: [Tag]?
    fileprivate var _documentDescription: String?
    fileprivate let _dateFormatter: DateFormatter

    init(path: URL, delegate: TagsDelegate) {
        self.path = path
        self.delegate = delegate

        // create a filename and rename the document
        self.name = String(path.lastPathComponent)

        // initialize the date formatter
        self._dateFormatter = DateFormatter()
        self._dateFormatter.dateFormat = "yyyy-MM-dd"

        // try to parse the current filename
        // parse the date
        if var dateRaw = regex_matches(for: "^\\d{4}-\\d{2}-\\d{2}--", in: self.name!),
           let date = self._dateFormatter.date(from: String(dateRaw[0].dropLast(2))) {
            self.documentDate = date
        }

        // parse the description
        if var raw = regex_matches(for: "--[a-zA-Z0-9-]+__", in: self.name!) {
            self._documentDescription = getSubstring(raw[0], startIdx: 2, endIdx: -2)
        }

        // parse the tags
        if var raw = regex_matches(for: "__[a-zA-Z0-9_]+.[pdfPDF]{3}$", in: self.name!) {
            // parse the tags of a document
            let documentTagNames = getSubstring(raw[0], startIdx: 2, endIdx: -4).components(separatedBy: "_")
            // get the available tags of the archive
            let availableTags = self.delegate?.getTagList() ?? []
            
            self.documentTags = [Tag]()
            for documentTagName in documentTagNames {
                if availableTags.contains(where: { $0.name == documentTagName }) {
                    os_log("Tag already found in archive tags.", log: self.log, type: .debug)
                    for availableTag in availableTags where availableTag.name == documentTagName {
                        self.documentTags!.append(availableTag)
                    }
                } else {
                    os_log("Tag not found in archive tags.", log: self.log, type: .debug)
                    self.documentTags!.append(Tag(name: documentTagName, count: 0))
                }
            }
        }
    }

    func rename(archivePath: URL) -> Bool {
        let new_basepath: URL
        let filename: String
        do {
            (new_basepath, filename) = try getRenamingPath(archivePath: archivePath)
        } catch DocumentError.description {
            dialogOK(message_key: "renaming_failed", info_key: "check_document_description", style: .warning)
            return false
        } catch DocumentError.tags {
            dialogOK(message_key: "renaming_failed", info_key: "check_document_tags", style: .warning)
            return false
        } catch {
            dialogOK(message_key: "renaming_failed", info_key: "check_document_fields", style: .warning)
            return false
        }
        
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
            os_log("Error while moving file: %@", log: self.log, type: .error, error as CVarArg)
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
            let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "DataModel")
            os_log("Could not set file: %@", log: self.log, type: .error, error as CVarArg)
        }
        return true
    }
    
    internal func getRenamingPath(archivePath: URL) throws -> (new_basepath: URL, filename: String) {
        // create a filename and rename the document
        guard let tags = self.documentTags,
              tags.count > 0 else {
                throw DocumentError.tags
        }
        guard let description = self.documentDescription,
              description != "" else {
            throw DocumentError.description
        }
        
        // get date
        let date_str = self._dateFormatter.string(from: self.documentDate)
        
        // get tags
        var tag_str = ""
        for tag in tags.sorted(by: { $0.name < $1.name }) {
            tag_str += "\(tag.name)_"
        }
        tag_str = String(tag_str.dropLast(1))
        
        // create new filepath
        let filename = "\(date_str)--\(description)__\(tag_str).pdf"
        let new_basepath = archivePath.appendingPathComponent(String(date_str.prefix(4)))
    
        return (new_basepath, filename)
    }
}

enum DocumentError: Error {
    case description
    case tags
}
