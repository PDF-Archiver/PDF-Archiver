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
    var documentIdx: Int? {
        get {
            return self._documentIdx
        }
        set {
            let documents = self.documents ?? []
            if let raw = newValue, raw < documents.count {
                self._documentIdx = raw
            } else {
                self._documentIdx = 0
            }
        }
    }
    fileprivate var _documentIdx: Int?

    init() {
        self.prefs = Preferences(delegate: self as TagsDelegate)
    }
    
    func addNewDocuments(paths: [URL]) {
        for pdf_path in paths {
            let selectedDocument = Document(path: pdf_path, delegate: self as TagsDelegate)
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
    }

    func getTagList() -> Set<Tag> {
        return self.tags ?? []
    }
}
