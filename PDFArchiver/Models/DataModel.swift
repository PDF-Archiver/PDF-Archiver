//
//  DataModel.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 26.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation
import os.log

protocol DataModelTagsDelegate: class {
    func updateView(updatePDF: Bool)
    func setTagList(tagList: Set<Tag>)
    func getTagList() -> Set<Tag>
    func addUntaggedDocuments(paths: [URL])
}

class DataModel: Logging {
    weak var viewControllerDelegate: ViewControllerDelegate?
    weak var onboardingVCDelegate: OnboardingVCDelegate?
    var prefs = Preferences()
    var archive = Archive()
    var store = IAPHelper()
    var tags = Set<Tag>()
    var untaggedDocuments = [Document]() {
        didSet {
            // add documents to the GUI
            self.viewControllerDelegate?.setDocuments(documents: self.untaggedDocuments)
        }
    }

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
                result = document.rename(archivePath: archivePath)
            }

            if result {
                self.viewControllerDelegate?.setDocuments(documents: self.untaggedDocuments)
                return true
            }
        }
        return false
    }

    func trashDocument(_ document: Document) -> Bool {
        var trashed = false
        self.prefs.accessSecurityScope {
            let fileManager = FileManager.default
            do {
                try fileManager.trashItem(at: document.path, resultingItemURL: nil)
                self.untaggedDocuments.remove(document)
                trashed = true

            } catch let error {
                os_log("Can not trash file: %@", log: self.log, type: .debug, error.localizedDescription)
            }
        }
        return trashed
    }

    func filterTags(prefix: String) -> Set<Tag> {
        let tags = self.tags.filter { tag in
            return tag.name.hasPrefix(prefix)
        }
        return tags
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
        if document.documentTags.remove(tag) != nil {
            tag.count -= 1
        }

        // update the view, e.g. tag counts
        self.viewControllerDelegate?.updateView(updatePDF: false)
    }

    @discardableResult
    func add(tag: Tag, to document: Document) -> Bool {
        // test if tag already exists in document tags
        for documentTag in document.documentTags where documentTag.name == tag.name {
            os_log("Tag '%@' already found!", log: self.log, type: .error, tag.name)
            return false
        }

        // add the new tag
        document.documentTags.insert(tag)

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
        self.viewControllerDelegate?.updateView(updatePDF: updatePDF)
    }

    func setTagList(tagList: Set<Tag>) {
        self.tags = tagList
    }

    func getTagList() -> Set<Tag> {
        return tags
    }

    func addUntaggedDocuments(paths: [URL]) {
        // remove the tag count from the old documents
        for document in self.untaggedDocuments {
            for tag in document.documentTags {
                tag.count -= 1
            }
        }

        // access the file system and add documents to the data model
        self.prefs.accessSecurityScope {
            var documents = [Document]()
            for path in paths {
                let files = self.archive.getPDFs(path)
                for file in files {
                    documents.append(Document(path: file, availableTags: &self.tags))
                }
            }
            self.untaggedDocuments = documents
        }
    }

}
