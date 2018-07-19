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
    func updateDocumentsAndTags()
}

class Archive: ArchiveDelegate, Logging {
    var documents = [Document]()
    weak var preferencesDelegate: PreferencesDelegate?
    weak var dataModelTagsDelegate: DataModelTagsDelegate?

    func updateDocumentsAndTags() {
        guard let archivePath = self.preferencesDelegate?.archivePath else {
            os_log("No archive path found.", log: self.log, type: .fault)
            return
        }

        // access the file system
        self.preferencesDelegate?.accessSecurityScope {

            // get year archive folders
            var folders = [URL]()
            do {
                let fileManager = FileManager.default
                folders = try fileManager.contentsOfDirectory(at: archivePath, includingPropertiesForKeys: [.nameKey], options: .skipsHiddenFiles)
                    // only show folders no files
                    .filter({ $0.hasDirectoryPath })
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
                let filesInFolder = self.getPDFs(folder)
                files.append(contentsOf: filesInFolder)
            }

            // update the taggedDocuments
            self.documents = [Document]()
            var tags = self.dataModelTagsDelegate?.getTagList() ?? []
            for file in files {
                self.documents.append(Document(path: file, availableTags: &tags))
            }
            self.dataModelTagsDelegate?.setTagList(tagList: tags)
        }
    }

    func getPDFs(_ sourceFolder: URL) -> [URL] {
        // get all files in the source folder
        let fileManager = FileManager.default
        let files = (fileManager.enumerator(at: sourceFolder,
                                            includingPropertiesForKeys: nil,
                                            options: [.skipsHiddenFiles],
                                            errorHandler: nil)?.allObjects as? [URL]) ?? []

        // pick pdfs and convert pictures
        var pdfURLs = [URL]()
        for file in files {
            if file.pathExtension == "pdf" {
                // add PDF
                pdfURLs.append(file)

            } else if let fileTypeIdentifier = file.typeIdentifier,
                NSImage.imageTypes.contains(fileTypeIdentifier),
                self.preferencesDelegate?.convertPictures ?? false {
                // convert picture/supported file to PDF
                let pdfURL = convertToPDF(file)
                pdfURLs.append(pdfURL)

            } else {
                // skip the unsupported filetype
                continue
            }
        }

        return pdfURLs
    }
}
