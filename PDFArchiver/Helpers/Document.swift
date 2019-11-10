//
//  Document.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 14.06.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import Foundation
import os.log

extension Document {

    static func createFilename(date: Date, specification: String?, tags: Set<String>) -> String {

        // get formatted date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: date)

        // get description
        let newSpecification: String = specification ?? Constants.documentDescriptionPlaceholder + Date().timeIntervalSince1970.description

        // parse the tags
        let foundTags = !tags.isEmpty ? tags : Set([Constants.documentTagPlaceholder])
        let tagStr = Array(foundTags).sorted().joined(separator: "_")

        // create new filepath
        return "\(dateStr)--\(newSpecification)__\(tagStr).pdf"
    }

    func cleaned() -> Document {
        // cleanup the found document
        if let tag = tags.first(where: { $0 == Constants.documentTagPlaceholder }) {
            tags.remove(tag)
        }
        if specification.contains(Constants.documentDescriptionPlaceholder) {
            specification = ""
        }

        return self
    }

    func download() {
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: path)
            downloadStatus = .downloading(percentDownloaded: 0)
        } catch {
            assertionFailure("Could not download document '\(filename)' - errored:\n\(error.localizedDescription)")
            os_log("%s", log: Document.log, type: .debug, error.localizedDescription)
        }
    }

    func delete(in archive: Archive) {
        let documentPath: URL
        if downloadStatus == .local {
            documentPath = path
        } else {
            let iCloudFilename = ".\(filename).icloud"
            documentPath = path.deletingLastPathComponent().appendingPathComponent(iCloudFilename)
        }

        do {
            try FileManager.default.removeItem(at: documentPath)
            archive.remove(Set([self]))

        } catch {
// TODO: handle error
//            let alert = UIAlertController(title: NSLocalizedString("ArchiveViewController.delete_failed.title", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
//            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Button confirmation label"), style: .default, handler: nil))
//            self.present(alert, animated: true, completion: nil)
        }
    }
}
