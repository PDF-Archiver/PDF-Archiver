//
//  DataModel.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 26.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import Foundation
import os.log
import Quartz

protocol DataModelDelegate: AnyObject {
    func moveArchivedDocuments(from oldArchivePath: URL, to newArchivePath: URL)
    func updateArchivedDocuments()
    func updateUntaggedDocuments(paths: [URL])
    func savePreferences()
    func updateView(_ options: UpdateOptions)
}

extension DataModel {
    public enum DocumentOrder: String {
        case status
        case name
    }

    public enum TagOrder: String {
        case count
        case name
    }
}

public class DataModel: NSObject, DataModelDelegate, Logging {
    weak var viewControllerDelegate: ViewControllerDelegate?
    weak var onboardingVCDelegate: OnboardingVCDelegate?
    var prefs = Preferences()
    private let archive = Archive()
    let store = IAPHelper()

    // selected document
    public var selectedDocument: Document?

    // document table view
    public private(set) var sortedDocuments = [Document]()
    public var documentSortOrder = DataModel.DocumentOrder.name {
        didSet { refreshDocuments() }
    }
    public var docuementSortAscending = true {
        didSet { refreshDocuments() }
    }

    // tag table view
    public private(set) var sortedTags = [Tag]()
    public var tagSortOrder = DataModel.TagOrder.count {
        didSet { refreshTags() }
    }
    public var tagSortAscending = true {
        didSet { refreshTags() }
    }
    public var tagFilterTerm = "" {
        didSet { refreshTags() }
    }

    // MARK: - Search Functions
    private func refreshDocuments() {

        // get all documents
        let allDocuments = archive.get(scope: .all, searchterms: [], status: .untagged)

        // sort documents
        switch documentSortOrder {
        case .status:
            sortedDocuments = allDocuments.sorted { $0.taggingStatus < $1.taggingStatus }
        case .name:
            sortedDocuments = allDocuments.sorted { $0.filename < $1.filename }
        }
        if docuementSortAscending {
            sortedTags.reverse()
        }
    }

    private func refreshTags() {

        // get all tags
        let allTags = archive.getAvailableTags(with: [tagFilterTerm])

        // sort documents
        switch tagSortOrder {
        case .count:
            sortedTags = allTags.sorted { $0.count < $1.count }
        case .name:
            sortedTags = allTags.sorted { $0.name < $1.name }
        }
        if tagSortAscending {
            sortedTags.reverse()
        }
    }

    override init() {
        super.init()

        // set delegates
        self.prefs.dataModelDelegate = self
        self.prefs.archiveDelegate = archive

        // documents from the observed path
        if let observedPath = self.prefs.observedPath {
            self.updateUntaggedDocuments(paths: [observedPath])
        }

        // update the archive documents and tags
        DispatchQueue.global().async {
            self.updateArchivedDocuments()
        }
    }

    // MARK: - API Functions

    public func updateArchivedDocuments() {
        guard let archivePath = prefs.archivePath else {
            os_log("No archive path found.", log: self.log, type: .fault)
            return
        }

        // access the file system
        prefs.accessSecurityScope {

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
                prefs.archiveModificationDate = attributes[FileAttributeKey.modificationDate] as? Date

            } catch {
                os_log("An error occured while getting the archive year folders.", log: self.log, type: .error)
            }

            // only use the latest two year folders by default
            if !(prefs.analyseAllFolders) {
                folders = Array(folders.prefix(2))
            }

            // get all PDF files from this year and the last years
            let convertPictures = prefs.convertPictures
            for folder in folders {
                for file in convertAndGetPDFs(folder, convertPictures: convertPictures) {
                    // TODO: add the real document size here?
                    archive.add(from: file, size: nil, downloadStatus: .local, status: .tagged)
                }
            }

            // refresh the tags
            self.refreshTags()

            // update the tag table view
            self.updateView(.tags)
        }
    }

    public func updateUntaggedDocuments(paths: [URL]) {

        // remove the tag count from the old documents
        archive.removeAll(.untagged)

        // access the file system and add documents to the data model
        self.prefs.accessSecurityScope {
            let convertPictures = prefs.convertPictures
            for path in paths {
                for file in convertAndGetPDFs(path, convertPictures: convertPictures) {
                    // TODO: add correct size here?
                    archive.add(from: file, size: nil, downloadStatus: .local, status: .untagged)
                }
            }

            // update the sorted documents
            refreshDocuments()
        }
    }

    public func moveArchivedDocuments(from oldArchivePath: URL, to newArchivePath: URL) {
        if oldArchivePath == newArchivePath {
            return
        }

        prefs.accessSecurityScope {

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

    public func savePreferences() {
        let tags = archive.getAvailableTags(with: [])
        prefs.save(with: tags)
    }

    public func addTagToSelectedDocument(_ tagName: String) {

        guard let selectedDocument = selectedDocument else {
                os_log("No document is currently selected!", log: self.log, type: .info)
                return
        }

        // add new tag to document
        archive.add(tag: tagName, to: selectedDocument)
    }

    // TODO: refactor this ... do we need this in the delegate?
    public func updateView(_ options: UpdateOptions) {
        DispatchQueue.main.async {
            self.viewControllerDelegate?.updateView(options)
        }
    }

    // MARK: - Helper Functions
    private func convertAndGetPDFs(_ sourceFolder: URL, convertPictures: Bool) -> [URL] {
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
                convertPictures {

                // get the output path
                var outPath = file
                outPath.deletePathExtension()
                outPath = outPath.appendingPathExtension("pdf")
                pdfURLs.append(outPath)

                if firstConvertedDocument {
                    // convert the first picture on the current thread
                    convertToPDF(from: file, to: outPath)
                    // do not update the view after the first document anymore
                    firstConvertedDocument = false
                    // update the view
                    updateView([.selectedDocument, .documents])
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

    private func convertToPDF(from inPath: URL, to outPath: URL) {
        // Create an empty PDF document
        let pdfDocument = PDFDocument()

        // Create a PDF page instance from the image
        let image = NSImage(byReferencing: inPath)
        guard let pdfPage = PDFPage(image: image) else { fatalError("No PDF page found.") }

        // Insert the PDF page into your document
        pdfDocument.insert(pdfPage, at: 0)

        // save the pdf document
        prefs.accessSecurityScope {
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

    // TODO: THE FOLLOWING IS OTHER STUFF

    func saveDocumentInArchive() -> Bool {

        guard let selectedDocument = selectedDocument else { return false }

        if let archivePath = self.prefs.archivePath {
            // rename the document
            var result = false

            self.prefs.accessSecurityScope {

                do {
                    result = try selectedDocument.rename(archivePath: archivePath, slugify: self.prefs.slugifyNames)
                } catch {
                    // TODO: add error handling here
//                dialogOK(messageKey: "save_failed", infoKey: "file_already_exists", style: .warning)
//                dialogOK(messageKey: "save_failed", infoKey: error.localizedDescription, style: .warning)
                }
            }

            if result {
                // TODO: select the next document

                // update the documents
                viewControllerDelegate?.updateView(.all)

                // increment count an request a review?
                AppStoreReviewRequest.shared.incrementCount()

                return true
            }
        }
        return false
    }

    func trashDocument(_ document: Document) -> Bool {
        var trashed = false

        archive.remove(Set([document]))
        self.prefs.accessSecurityScope {
            let fileManager = FileManager.default
            do {
                try fileManager.trashItem(at: document.path, resultingItemURL: nil)
                trashed = true

            } catch let error {
                os_log("Can not trash file: %@", log: self.log, type: .debug, error.localizedDescription)
            }
        }
        return trashed
    }

    func setDocumentDescription(document: Document, description: String) {
        // set the description of the pdf document
        if self.prefs.slugifyNames {
            document.specification = description.slugify()
        } else {
            document.specification = description
        }
    }

    func remove(tag: Tag, from document: Document) {
        // remove the selected element
        if document.tags.remove(tag) != nil {
            archive.remove(tag.name)
        }
    }
}
