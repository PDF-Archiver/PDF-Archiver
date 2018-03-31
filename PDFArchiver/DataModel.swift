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
    var prefs: Preferences?
    var documents: [Document]?
    var tags: Set<Tag>?
    var selectedDocument: Document?
    fileprivate var _documentIdx: Int?

    init() {
        self.prefs = Preferences(delegate: self as TagsDelegate)
        self.documents = []
    }

    func addDocuments(paths: [URL]) {
        // clear old documents
        self.documents = []

        // add documents to the data model
        for path in paths {
            let files = getPDFs(url: path)
            for file in files {
                let selectedDocument = Document(path: file, delegate: self as TagsDelegate)
                self.documents?.append(selectedDocument)
            }
        }
        // add documents to the GUI
        if let documents = self.documents {
            self.viewControllerDelegate?.setDocuments(documents: documents)
        }
    }

    func filterTags(prefix: String) -> Set<Tag> {
        let tags = (self.tags ?? []).filter { tag in
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
        return self.tags ?? []
    }
}
