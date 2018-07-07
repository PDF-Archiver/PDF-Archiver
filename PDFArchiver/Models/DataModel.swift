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
    func setTagList(tagList: Set<Tag>)
    func getTagList() -> Set<Tag>
    func updateTags()
    func addUntaggedDocuments(paths: [URL])
}
protocol DataModelGUIDelegate: class {
    // TODO: test if this really closes the app from onboardingVC (when a user has not bought the app)
    func updateGUI()
    func closeOnboardingView()
    func closeApp()
}

class DataModel: DataModelTagsDelegate {
    fileprivate let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "DataModel")
    weak var viewControllerDelegate: ViewControllerDelegate?
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
        self.prefs.tagsDelegate = self as DataModelTagsDelegate
        self.prefs.archiveDelegate = self.archive as ArchiveDelegate

        self.archive.tagsDelegate = self as DataModelTagsDelegate
        self.archive.preferencesDelegate = self.prefs as PreferencesDelegate

        // load preferences
        self.prefs.load()

        if let observedPath = self.prefs.observedPath {
            if !observedPath.startAccessingSecurityScopedResource() {
                os_log("Accessing Security Scoped Resource failed.", log: self.log, type: .fault)
                return
            }
            self.addUntaggedDocuments(paths: [observedPath])
            observedPath.stopAccessingSecurityScopedResource()
        }
    }

    func saveDocumentInArchive(document: Document) -> Bool {
        if let archivePath = self.prefs.archivePath {
            return document.rename(archivePath: archivePath)
        }
        return false
    }

    func trashDocument(_ document: Document) -> Bool {
        let fileManager = FileManager.default
        do {
            try fileManager.trashItem(at: document.path, resultingItemURL: nil)
            if let index = self.archive.documents.index(of: document) {
                self.archive.documents.remove(at: index)
            }
            return true

        } catch let error {
            os_log("Can not trash file: %@", log: self.log, type: .debug, error.localizedDescription)
            return false
        }
    }

    func updateTags() {
        // get tags and counts from filename
        var tagsRaw: [String] = []
        for file in self.archive.documents + self.untaggedDocuments {
            let matched = regexMatches(for: "_[a-z0-9]+", in: file.path.lastPathComponent) ?? []
            for tag in matched {
                tagsRaw.append(String(tag.dropFirst()))
            }
        }

        // clear the old tags
        self.tags = Set<Tag>()

        // get the old tags
        let tagsDict = tagsRaw.reduce(into: [:]) { counts, word in counts[word, default: 0] += 1 }
        for (name, count) in tagsDict {
            self.tags.insert(Tag(name: name, count: count))
        }
    }

    func filterTags(prefix: String) -> Set<Tag> {
        let tags = self.tags.filter { tag in
            return tag.name.hasPrefix(prefix)
        }
        return tags
    }

    func addUntaggedDocuments(paths: [URL]) {
        // clear old documents
        self.untaggedDocuments = []

        // access the file system and add documents to the data model
        self.prefs.accessSecurityScope {
            for path in paths {
                let files = getPDFs(path)
                for file in files {
                    self.untaggedDocuments.append(Document(path: file, availableTags: &self.tags))
                }
            }
        }

        // update the tags
        self.updateTags()
    }

    // MARK: - delegate functions
    func setTagList(tagList: Set<Tag>) {
        self.tags = tagList
    }

    func getTagList() -> Set<Tag> {
        return self.tags
    }
}

// MARK: - DataModelGUIDelegate extension

extension DataModel: DataModelGUIDelegate {
    func updateGUI() {
        // TODO:
        print("Update the GUI")
    }

    func closeOnboardingView() {
        // TODO:
        print("close a view")
    }

    func closeApp() {
        // TODO:
        print("closes the app")
    }
}
