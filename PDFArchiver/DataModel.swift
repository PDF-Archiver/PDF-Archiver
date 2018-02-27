//
//  DataModel.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 26.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

class DataModel: PreferencesDelegate {
    var prefs: Preferences?
    var documents: [Document]?
    var tags: TagList?
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
        self.prefs = Preferences(delegate: self as PreferencesDelegate)
    }

    // MARK: - delegate functions
    func setTagList(tagDict: [String: Int]) {
        self.tags = TagList(tags: tagDict)
    }

    func getTagList() -> [String: Int] {
        var tags: [String: Int] = [:]
        for tag in self.tags?.list ?? [] {
            tags[tag.name] = tag.count
        }
        return tags
    }
}
