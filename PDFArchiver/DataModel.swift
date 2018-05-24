//
//  DataModel.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 26.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation
import os.log

protocol TagsDelegate: class {
    func setTagList(tagList: Set<Tag>)
    func getTagList() -> Set<Tag>
}

class DataModel: TagsDelegate {
    let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "DataModel")
    weak var viewControllerDelegate: ViewControllerDelegate?
    var prefs = Preferences()
    var documents: [Document]
    var tags: Set<Tag>
    var store: IAPHelper

    init() {
        let availableIds = Set(["DONATION_LEVEL1", "DONATION_LEVEL2", "DONATION_LEVEL3"])
        self.store = IAPHelper(productIds: availableIds)
        self.documents = []
        self.tags = []
        self.prefs.delegate = self as TagsDelegate
        self.prefs.load()

        // get the product list
        self.updateMASStatus()
    }

    func updateMASStatus() {
        self.store.requestProducts {success, products in
            if success {
                self.store.products = products!

                NotificationCenter.default.post(name: Notification.Name("MASUpdateStatus"), object: true)
            }
        }
    }

    func updateTags() {
        self.tags = []

        // get tags
        self.prefs.getArchiveTags()

        // access the file system and get the new documents
        self.documents = []

        // add documents
        if let observedPath = self.prefs.observedPath {
            self.viewControllerDelegate?.accessSecurityScope {
                self.addDocuments(paths: [observedPath])
            }
        }
    }

    func addDocuments(paths: [URL]) {
        // clear old documents
        self.documents = []

        // access the file system and add documents to the data model
        self.viewControllerDelegate?.accessSecurityScope {
            for path in paths {
                let files = getPDFs(url: path)
                for file in files {
                    self.documents.append(Document(path: file, delegate: self as TagsDelegate))
                }
            }
        }

        // add documents to the GUI
        self.viewControllerDelegate?.setDocuments(documents: documents)
    }

    func filterTags(prefix: String) -> Set<Tag> {
        let tags = self.tags.filter { tag in
            return tag.name.hasPrefix(prefix)
        }
        return tags
    }

    // MARK: - delegate functions
    func setTagList(tagList: Set<Tag>) {
        self.tags = tagList
    }

    func getTagList() -> Set<Tag> {
        return self.tags
    }
}
