//
//  DataModel.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 26.01.18.
//  Copyright © 2020 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import Foundation
import os.log
import Quartz

protocol DataModelDelegate: AnyObject {
    func updateArchivedDocuments()
    func updateUntaggedDocuments(paths: [URL])
    func moveArchivedDocuments(from oldArchivePath: URL, to newArchivePath: URL)
    func savePreferences()
}

extension DataModel {
    public enum DocumentOrder: String {
        case taggingStatus
        case filename
    }

    public enum TagOrder: String {
        case count
        case name
    }
}

public class DataModel: NSObject, DataModelDelegate, Logging {
    weak var viewControllerDelegate: ViewControllerDelegate?
    var prefs = Preferences()
    private let archive = Archive()

    static let environment: Environment = {
        // return early, if we have a debug build
        #if DEBUG
        return .develop
        #else
        // source from: https://stackoverflow.com/a/38984554
        if let url = Bundle.main.appStoreReceiptURL {
            if url.path.contains("CoreSimulator") {
                return .develop
            } else if url.lastPathComponent == "sandboxReceipt" {
                return .testflight
            }
        }
        return .release
        #endif
    }()
    static let store = IAPHelper(productIdentifiers: Set(["DONATION_LEVEL1", "DONATION_LEVEL2", "DONATION_LEVEL3", "SUBSCRIPTION_MONTHLY", "SUBSCRIPTION_YEARLY"]),
                                 environment: environment,
                                 apiKey: "EfDOhpHSYceHyPlraALHuiADMcQeXVsj",
                                 preSubscriptionPrefixes: ["1.0", "1.1.", "1.2."])

    // selected document
    public var selectedDocument: Document? {
        didSet {
            guard let selectedDocument = selectedDocument else { return }
            archive.cancelOperations(on: selectedDocument)
        }
    }

    // document table view
    public private(set) var sortedDocuments = [Document]()
    public var documentSortDescriptors = [NSSortDescriptor(key: DocumentOrder.taggingStatus.rawValue, ascending: false),
                                          NSSortDescriptor(key: DocumentOrder.filename.rawValue, ascending: true)] {
        didSet { refreshDocuments() }
    }

    // tag table view
    public private(set) var sortedTags = [Tag]()
    public var tagSortDescriptors = [NSSortDescriptor(key: TagOrder.count.rawValue, ascending: false),
                                     NSSortDescriptor(key: TagOrder.name.rawValue, ascending: true)] {
        didSet { refreshTags() }
    }
    public var tagFilterTerm = "" {
        didSet { refreshTags() }
    }

    // MARK: - Search Functions
    private func refreshDocuments() {

        // merge the untagged and already tagged documents
        let untaggedDocuments = archive.get(scope: .all, searchterms: [], status: .untagged)

        // get only already tagged documents (trashed documents would not be removed otherwise)
        let sortedTaggedDocuments = Set(sortedDocuments.filter { $0.taggingStatus == .tagged })

        // merge these document sets
        let newSortableDocuments = Array(sortedTaggedDocuments.union(untaggedDocuments))

        // sort and save the tags again
        sortedDocuments = (try? sort(newSortableDocuments, by: documentSortDescriptors)) ?? []
    }

    private func refreshTags() {

        // get all tags
        let allTags = Array(archive.getAvailableTags(with: [tagFilterTerm]))

        // sort and save the tags again
        sortedTags = (try? sort(allTags, by: tagSortDescriptors)) ?? []
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

            // update the tag table view
            DispatchQueue.main.async {
                self.viewControllerDelegate?.updateView(.tags)
            }
        }
    }

    // MARK: - API Functions

    public func updateArchivedDocuments() {
        guard let archivePath = prefs.archivePath else {
            os_log("No archive path found.", log: self.log, type: .fault)
            return
        }

        // access the file system
        try? prefs.accessSecurityScope {

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

            // remove all old documents
            archive.remove(archive.get(scope: .all, searchterms: [], status: .tagged))

            // only use the latest two year folders by default
            if !(prefs.analyseAllFolders) {
                folders = Array(folders.prefix(2))
            }

            // get all PDF files from this year and the last years
            for folder in folders {
                for file in convertAndGetPDFs(folder, convertPictures: prefs.convertPictures) {

                    archive.add(from: file, size: nil, downloadStatus: .local, status: .tagged, parse: [])
                }
            }

            // refresh the tags
            self.refreshTags()
        }
    }

    public func updateUntaggedDocuments(paths: [URL]) {

        // remove the tag count from the old documents
        archive.removeAll(.untagged)

        // access the file system and add documents to the data model
        try? prefs.accessSecurityScope {

            // setup the parsing options for the first document, e.g. use the main thread
            var paringOptions: ParsingOptions = [.all, .mainThread]

            for path in paths {
                for file in convertAndGetPDFs(path, convertPictures: prefs.convertPictures) {

                    // add new document
                    archive.add(from: file, size: nil, downloadStatus: .local, status: .untagged, parse: paringOptions)

                    // use another thread for all other documents
                    if paringOptions.contains(.mainThread) {
                        paringOptions = .all
                    }
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

        try? prefs.accessSecurityScope {

            // get all document folders that should be moved
            let fileManager = FileManager.default
            guard let documentsToBeMoved = fileManager.enumerator(at: oldArchivePath,
                                                                  includingPropertiesForKeys: nil,
                                                                  options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
                                                                  errorHandler: nil) else { return }

            for folder in documentsToBeMoved {

                // get path and move the folder
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

    public func updateArchivedTags() {

        // get all tagged documents
        let documents = archive.get(scope: .all, searchterms: [], status: .tagged)

        // access the file system and add documents to the data model
        try? prefs.accessSecurityScope {

            for document in documents {
                document.saveTagsToFilesystem()
            }
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
            if file.pathExtension.lowercased() == "pdf" {

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
                    DispatchQueue.main.async {
                        self.viewControllerDelegate?.updateView([.selectedDocument, .documents])
                    }
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
        do {
            try prefs.accessSecurityScope {
                pdfDocument.write(to: outPath)

                // trash old pdf
                try FileManager.default.trashItem(at: inPath, resultingItemURL: nil)
            }
        } catch let error {
            os_log("Can not trash file: %@", log: self.log, type: .debug, error.localizedDescription)
        }
    }

    // MARK: - other functions

    func saveDocumentInArchive() throws {

        guard let selectedDocument = selectedDocument else { throw DataModelError.noDocumentSelected }
        if let archivePath = self.prefs.archivePath {

            // try to move the document
            try prefs.accessSecurityScope {
                try selectedDocument.rename(archivePath: archivePath, slugify: prefs.slugifyNames)
            }
        }
    }

    func trashDocument(_ document: Document) throws {

        try prefs.accessSecurityScope {

            // try to delete the document from the file system
            try FileManager.default.trashItem(at: document.path, resultingItemURL: nil)

            // remove document from the archive
            self.archive.remove(Set([document]))

            // update the sorted documents
            self.refreshDocuments()
        }
    }

    func setDocumentDescription(document: Document, description: String) {

        // set the description of the pdf document
        if prefs.slugifyNames {
            document.specification = description.slugified()
        } else {
            document.specification = description
        }
    }

    func remove(tag: Tag, from document: Document) {

        // remove the selected element
        if document.tags.remove(tag) != nil {
            archive.removeTag(tag.name)
        }
    }
}

enum DataModelError: Error {
    case noDocumentSelected
}

extension DataModelError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noDocumentSelected:
            return NSLocalizedString("document_error_description__no_document_selected", comment: "")
        }
    }

    var failureReason: String? {
        switch self {
        case .noDocumentSelected:
            return NSLocalizedString("document_failure_reason__no_document_selected", comment: "")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noDocumentSelected:
            return NSLocalizedString("document_error_description__no_document_selected", comment: "")
        }
    }
}
