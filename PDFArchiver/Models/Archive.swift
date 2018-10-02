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
    func moveArchivedDocuments(from oldArchivePath: URL, to newArchivePath: URL)
    func updateDocumentsAndTags()
}

class Archive: ArchiveDelegate, Logging {
    var documents = [Document]()
    weak var preferencesDelegate: PreferencesDelegate?
    weak var dataModelTagsDelegate: DataModelTagsDelegate?

    func moveArchivedDocuments(from oldArchivePath: URL, to newArchivePath: URL) {
        if oldArchivePath == newArchivePath {
            return
        }

        self.preferencesDelegate?.accessSecurityScope {

            let fileManager = FileManager.default
            guard let documentsToBeMoved = fileManager.enumerator(at: oldArchivePath,
                                                                  includingPropertiesForKeys: nil,
                                                                  options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
                                                                  errorHandler: nil) else { return }

            for folder in documentsToBeMoved {
                guard let folderPath = folder as? URL else { continue }
                try? fileManager.moveItem(at: folderPath,
                                          to: newArchivePath.appendingPathComponent(folderPath.lastPathComponent))
            }
        }
    }

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
                    .filter { $0.hasDirectoryPath }
                    // only show folders with year numbers
                    .filter { URL(fileURLWithPath: $0.path).lastPathComponent.prefix(2) == "20" || URL(fileURLWithPath: $0.path).lastPathComponent.prefix(2) == "19" }
                    // sort folders by year
                    .sorted { $0.path > $1.path }

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

            // get the tags from already tagged "untaggedDocuments"
            var tags = Set<Tag>()
            for document in self.dataModelTagsDelegate?.getUntaggedDocuments() ?? [] {
                for tag in document.documentTags {
                    if let filteredTag = tags.first(where: { $0.name == tag.name }) {
                        filteredTag.count += 1
                    } else {
                        tag.count = 1
                        tags.insert(tag)
                    }
                }
            }

            // update the taggedDocuments
            self.documents = [Document]()
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
        var firstConvertedDocument = true
        var pdfURLs = [URL]()
        // sort files like documentAC sortDescriptors
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            if file.pathExtension == "pdf" {
                // add PDF
                pdfURLs.append(file)
            } else if let fileTypeIdentifier = file.typeIdentifier,
                NSImage.imageTypes.contains(fileTypeIdentifier),
                self.preferencesDelegate?.convertPictures ?? false {
                // get the output path
                var outPath = file
                outPath.deletePathExtension()
                outPath = outPath.appendingPathExtension("pdf")
                pdfURLs.append(outPath)
                if firstConvertedDocument {
                    // convert the first picture on the current thread
                    self.convertToPDF(from: file, to: outPath)
                    // do not update the view after the first document anymore
                    firstConvertedDocument = false
                    // update the view
                    self.dataModelTagsDelegate?.updateView(updatePDF: true)
                } else {
                    // convert all other pictures in the background
                    DispatchQueue.global(qos: .background).async {
                        self.convertToPDF(from: file, to: outPath)
                    }
                }
            }
        }
        return pdfURLs
    }

    func convertToPDF(from inPath: URL, to outPath: URL) {
        // Create an empty PDF document
        let pdfDocument = PDFDocument()

        // Create a PDF page instance from the image
        let image = NSImage(byReferencing: inPath)
        guard let pdfPage = PDFPage(image: image) else { fatalError("No PDF page found.") }

        // Insert the PDF page into your document
        pdfDocument.insert(pdfPage, at: 0)

        // save the pdf document
        self.preferencesDelegate?.accessSecurityScope {
            pdfDocument.write(to: outPath)

            // trash old pdf
            let fileManager = FileManager.default
            do {
                try fileManager.trashItem(at: inPath, resultingItemURL: nil)
            } catch let error {
                os_log("Can not trash file: %@", log: self.log, type: .debug, error.localizedDescription)
            }
        }
    }
}
