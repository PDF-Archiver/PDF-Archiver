//
//  DataModel.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 26.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

protocol TagsDelegate: class {
    func setTagList(tagList: Set<Tag>)
    func getTagList() -> Set<Tag>
}

class DataModel: TagsDelegate {
    weak var viewControllerDelegate: ViewControllerDelegate?
    var prefs = Preferences()
    var documents: [Document]
    var tags: Set<Tag>

    init() {
        self.documents = []
        self.tags = []
        self.prefs.delegate = self as TagsDelegate
        self.prefs.load()
    }

    func addDocuments(paths: [URL]) {
        // clear old documents
        self.documents = []

        // add documents to the data model
        for path in paths {
            let files = getPDFs(url: path)
            for file in files {
                self.documents.append(Document(path: file, delegate: self as TagsDelegate))
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
        NotificationCenter.default.post(name: Notification.Name("UpdateViewController"), object: nil)
    }

    func getTagList() -> Set<Tag> {
        return self.tags
    }
}
