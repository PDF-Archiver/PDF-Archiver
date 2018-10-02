//
//  Document.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 25.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation
import os.log

class Document: NSObject, Logging {
    // structure for PDF documents on disk
    var path: URL
    @objc var name: String
    @objc var documentDone: String {
        return self.alreadyRenamed ? "✔️" : ""
    }
    var alreadyRenamed = false
    var date = Date()
    var specification: String? {
        didSet {
            self.specification = self.specification?.replacingOccurrences(of: "_", with: "-").lowercased()
        }
    }
    var documentTags = Set<Tag>()

    init(path: URL, availableTags: inout Set<Tag>) {
        self.path = path

        // create a filename and rename the document
        self.name = String(path.lastPathComponent)

        // try to parse the current filename
        let parser = DateParser()
        var rawDate = ""
        if let parsed = parser.parse(self.name) {
            self.date = parsed.date
            rawDate = parsed.rawDate
        }

        // save a first "raw" specification
        self.specification = path.lastPathComponent
            // drop the already parsed date
            .dropFirst(rawDate.count)
            // drop the extension and the last .
            .dropLast(path.pathExtension.count + 1)
            // exclude tags, if they exist
            .components(separatedBy: "__")[0]
            // clean up all "_" - they are for tag use only!
            .replacingOccurrences(of: "_", with: "-")
            // remove a pre or suffix from the string
            .slugifyPreSuffix()

        // parse the specification and override it, if possible
        if var raw = self.name.capturedGroups(withRegex: "--([\\w\\d-]+)__") {
            self.specification = raw[0]
        }

        // parse the tags
        if var raw = self.name.capturedGroups(withRegex: "__([\\w\\d_]+).[pdfPDF]{3}$") {
            // parse the tags of a document
            let documentTagNames = raw[0].components(separatedBy: "_")

            // get the available tags of the archive
            for documentTagName in documentTagNames {
                if let availableTag = availableTags.filter({$0.name == documentTagName}).first {
                    availableTag.count += 1
                    self.documentTags.insert(availableTag)
                } else {
                    let newTag = Tag(name: documentTagName, count: 1)
                    availableTags.insert(newTag)
                    self.documentTags.insert(newTag)
                }
            }
        }
    }

    @discardableResult
    func rename(archivePath: URL, slugify: Bool) -> Bool {
        let foldername: String
        let filename: String
        do {
            (foldername, filename) = try getRenamingPath(slugifyName: slugify)
        } catch {
            return false
        }

        // check, if this path already exists ... create it
        let newFilepath = archivePath
            .appendingPathComponent(foldername)
            .appendingPathComponent(filename)
        let fileManager = FileManager.default
        do {
            let folderPath = newFilepath.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: folderPath.path) {
                try fileManager.createDirectory(at: folderPath, withIntermediateDirectories: true, attributes: nil)
            }

            // test if the document name already exists in archive, otherwise move it
            if fileManager.fileExists(atPath: newFilepath.path),
               self.path != newFilepath {
                os_log("File already exists!", log: self.log, type: .error)
                dialogOK(messageKey: "renaming_failed", infoKey: "file_already_exists", style: .warning)
                return false
            } else {
                try fileManager.moveItem(at: self.path, to: newFilepath)
            }
        } catch let error as NSError {
            os_log("Error while moving file: %@", log: self.log, type: .error, error.description)
            dialogOK(messageKey: "renaming_failed", infoKey: error.localizedDescription, style: .warning)
            return false
        }
        self.name = String(newFilepath.lastPathComponent)
        self.path = newFilepath
        self.alreadyRenamed = true

        do {
            var tags = [String]()
            for tag in self.documentTags {
                tags += [tag.name]
            }

            // set file tags [https://stackoverflow.com/a/47340666]
            try (newFilepath as NSURL).setResourceValue(tags, forKey: URLResourceKey.tagNamesKey)
        } catch let error as NSError {
            os_log("Could not set file: %@", log: self.log, type: .error, error.description)
        }
        return true
    }

    internal func getRenamingPath(slugifyName: Bool) throws -> (foldername: String, filename: String) {
        // create a filename and rename the document
        guard self.documentTags.count > 0 else {
            dialogOK(messageKey: "renaming_failed", infoKey: "check_document_tags", style: .warning)
            throw DocumentError.tags
        }
        guard var specification = self.specification,
              specification != "" else {
            dialogOK(messageKey: "renaming_failed", infoKey: "check_document_description", style: .warning)
            throw DocumentError.description
        }

        // get formatted date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: self.date)

        // get description
        if slugifyName {
            specification = specification.slugify()
        }

        // get tags
        var tagStr = ""
        for tag in Array(self.documentTags).sorted(by: { $0.name < $1.name }) {
            tagStr += "\(tag.name)_"
        }
        tagStr = String(tagStr.dropLast(1))

        // create new filepath
        let filename = "\(dateStr)--\(specification)__\(tagStr).pdf"
        let foldername = String(dateStr.prefix(4))
        return (foldername, filename)
    }

    // MARK: - Other Stuff
    override var description: String {
        return "<Document \(self.name)>"
    }
}

enum DocumentError: Error {
    case description
    case tags
}
