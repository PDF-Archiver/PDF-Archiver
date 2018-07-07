//
//  Archive.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 07.07.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation
import os.log
import Quartz

protocol ArchiveDelegate: class {
    func updateDocuments()
}

class Archive: ArchiveDelegate {
    fileprivate let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Archive")
    var documents = [Document]()
    weak var preferencesDelegate: PreferencesDelegate?
    weak var tagsDelegate: DataModelTagsDelegate?
}

// MARK: - Archive delegate

extension Archive {

    func updateDocuments() {
        guard let archivePath = self.preferencesDelegate?.archivePath else {
            os_log("No archive path found.", log: self.log, type: .fault)
            return
        }

        // access the file system
        if !(archivePath.startAccessingSecurityScopedResource()) {
            os_log("Accessing Security Scoped Resource failed.", log: self.log, type: .fault)
            return
        }

        // get year archive folders
        var folders = [URL]()
        do {
            let fileManager = FileManager.default
            folders = try fileManager.contentsOfDirectory(at: archivePath, includingPropertiesForKeys: [.nameKey], options: .skipsHiddenFiles)
                // only show folders with year numbers
                .filter({ URL(fileURLWithPath: $0.path).lastPathComponent.prefix(2) == "20" || URL(fileURLWithPath: $0.path).lastPathComponent.prefix(2) == "19" })
                // sort folders by year
                .sorted(by: { $0.path > $1.path })

            // update the archiveModificationDate
            let attributes = try fileManager.attributesOfItem(atPath: archivePath.path)
            self.preferencesDelegate?.archiveModificationDate = attributes[FileAttributeKey.modificationDate] as? Date

        } catch {
            os_log("An error occured while getting the archive year folders.")
        }

        // only use the latest two year folders by default
        if !(self.preferencesDelegate?.analyseAllFolders ?? false) {
            folders = Array(folders.prefix(2))
        }

        // get all PDF files from this year and the last years
        var files = [URL]()
        for folder in folders {
            files.append(contentsOf: getPDFs(folder))
        }

        // update the taggedDocuments
        self.documents = [Document]()
        for file in files {
            // TODO: are these really the right files, e.g. pdf only?
            print(file)
            var tags = self.tagsDelegate?.getTagList() ?? []
            self.documents.append(Document(path: file, availableTags: &tags))
            self.tagsDelegate?.setTagList(tagList: tags)
        }

        // stop accessing the file system
        archivePath.stopAccessingSecurityScopedResource()
    }
}
