//
//  Archive.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 22.08.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

struct Archive {

    var documents = [Document]()
    var filteredDocuments = [Document]()
    var availableTags = Set<Tag>()
}
