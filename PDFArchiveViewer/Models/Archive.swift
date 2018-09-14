//
//  Archive.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 22.08.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

struct Archive {

    // TODO: do filtering documents here
    // TODO: save searchBar text + selected scopeButtonTitle here
    var allDocuments = [Document]()
    var filteredDocuments = [Document]()
    var availableTags = Set<Tag>()
}
