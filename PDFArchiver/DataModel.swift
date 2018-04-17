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
        self.store = IAPHelper(productIds: Set(["SUBSCRIPTION_LEVEL1", "SUBSCRIPTION_LEVEL2"]))
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

    func addDocuments(paths: [URL]) {
        // clear old documents
        self.documents = []

        // access the file system and add documents to the data model
        if !(self.prefs.archivePath?.startAccessingSecurityScopedResource() ?? false) {
            os_log("Accessing Security Scoped Resource failed.", log: self.log, type: .fault)
            return
        }
        for path in paths {
            let files = getPDFs(url: path)
            for file in files {
                self.documents.append(Document(path: file, delegate: self as TagsDelegate))
            }
        }
        self.prefs.archivePath?.stopAccessingSecurityScopedResource()

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
