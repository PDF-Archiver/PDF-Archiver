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
    var prefs: Preferences?
    var documents: [Document]?
    var tags: Set<Tag>?
    var selectedDocument: Document?
    fileprivate var _documentIdx: Int?

    init() {
        self.prefs = Preferences(delegate: self as TagsDelegate)
        self.documents = []
    }

    func addNewDocuments(paths: [URL]) {
        for path in paths {
            let selectedDocument = Document(path: path, delegate: self as TagsDelegate)
            self.documents?.append(selectedDocument)
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
