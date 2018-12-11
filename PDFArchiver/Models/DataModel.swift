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

protocol DataModelTagsDelegate: class {
    func updateView(updatePDF: Bool)
    func getUntaggedDocuments() -> [Document]
    func addUntaggedDocuments(paths: [URL])
//    func getTagManager() -> TagManager
}

class DataModel: Logging {
    weak var viewControllerDelegate: ViewControllerDelegate?
    weak var onboardingVCDelegate: OnboardingVCDelegate?
    var prefs = Preferences()
    let archive = Archive()
//    let tagManager = TagManager()
//    let untaggedDocumentsManager = UntaggedDocumentsManager()
    let store = IAPHelper()

    // TODO: use a set here
    var untaggedDocuments = [Document]()

    init() {
        // set delegates
        self.prefs.dataModelTagsDelegate = self as DataModelTagsDelegate
        self.prefs.archiveDelegate = self.archive as ArchiveDelegate

        self.archive.dataModelTagsDelegate = self as DataModelTagsDelegate
        self.archive.preferencesDelegate = self.prefs as PreferencesDelegate

        // documents from the observed path
        if let observedPath = self.prefs.observedPath {
            self.addUntaggedDocuments(paths: [observedPath])
        }

        // update the archive documents and tags
        DispatchQueue.global().async {
            self.archive.updateDocumentsAndTags()
        }
    }

    func saveDocumentInArchive(document: Document) -> Bool {
        if let archivePath = self.prefs.archivePath {
            // rename the document
            var result = false

            self.prefs.accessSecurityScope {

                do {
                    result = try document.rename(archivePath: archivePath, slugify: self.prefs.slugifyNames)
                } catch {
                    // TODO: add error handling here
//                dialogOK(messageKey: "save_failed", infoKey: "file_already_exists", style: .warning)
//                dialogOK(messageKey: "save_failed", infoKey: error.localizedDescription, style: .warning)
                }
            }

            if result {
                // update the documents
//                self.viewControllerDelegate?.setDocuments(documents: self.untaggedDocuments)
                viewControllerDelegate?.updateView(updatePDF: true)

                // increment count an request a review?
                AppStoreReviewRequest.shared.incrementCount()

                return true
            }
        }
        return false
    }

    func trashDocument(_ document: Document) -> Bool {
        var trashed = false
        guard let index = self.untaggedDocuments.index(of: document) else { return trashed }
        self.prefs.accessSecurityScope {
            let fileManager = FileManager.default
            do {
                try fileManager.trashItem(at: document.path, resultingItemURL: nil)
                self.untaggedDocuments.remove(at: index)
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
            tag.count -= 1
        }

        // update the view, e.g. tag counts
        self.viewControllerDelegate?.updateView(updatePDF: false)
    }

    @discardableResult
    func add(tag: Tag, to document: Document) -> Bool {
        // test if tag already exists in document tags
        for documentTag in document.tags where documentTag.name == tag.name {
            os_log("Tag '%@' already found!", log: self.log, type: .error, tag.name)
            return false
        }

        // add the new tag
        document.tags.insert(tag)

        // tag count update
        tag.count += 1

        // clear search field content
        self.viewControllerDelegate?.clearTagSearchField()

        // update the view
        self.viewControllerDelegate?.updateView(updatePDF: false)
        return true
    }
}

// MARK: - DataModel delegates

extension DataModel: DataModelTagsDelegate {
    func updateView(updatePDF: Bool) {
        DispatchQueue.main.async {
            self.viewControllerDelegate?.updateView(updatePDF: updatePDF)
        }
    }

    func getUntaggedDocuments() -> [Document] {
        return self.untaggedDocuments
    }

    func addUntaggedDocuments(paths: [URL]) {
        // remove the tag count from the old documents
        for document in self.untaggedDocuments {
            for tag in document.tags {
                tag.count -= 1
            }
        }

        // access the file system and add documents to the data model
        self.prefs.accessSecurityScope {
            var documents = [Document]()
            for path in paths {
                let files = self.archive.getPDFs(path)
                for file in files {
                    // TODO: add correct size here?
                    documents.append(Document(path: file, tagManager: tagManager, size: 0, downloadStatus: .local))
                }
            }
            self.untaggedDocuments = documents
        }
    }

    func getTagManager() -> TagManager {
        return tagManager
    }

}
