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
    var document_idx: Int?

    init() {
        self.prefs = Preferences(delegate: self as PreferencesDelegate)
    }

    // MARK: - delegate functions
    func setTagList(tagDict: Dictionary<String, Int>) {
        self.tags = TagList(tags: tagDict)
    }

    func getTagList() -> Dictionary<String, Int> {
        var tags: Dictionary<String, Int> = [:]
        for tag in self.tags?.list ?? [] {
            tags[tag.name] = tag.count
        }
        return tags
    }
}
