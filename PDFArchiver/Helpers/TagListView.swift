//
//  TagListView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 16.04.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation
import TagListView

extension TagListView {
    func updateTags(_ newTags: Set<String>) {
        removeAllTags()
        addTags(Array(newTags).sorted())
    }

    func addUniqueTag(_ title: String) {
        let currentTags = Set(self.tagViews.compactMap { $0.currentTitle })
        if !currentTags.contains(title) {
            self.addTag(title)
        }
    }
}
