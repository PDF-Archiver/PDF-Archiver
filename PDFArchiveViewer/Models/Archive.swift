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

    init() {
        // TODO: debug documents
        self.documents.append(Document(path: URL(fileURLWithPath: "test/2018/2018-05-12--test-dokument-1__tag1_tag2.pdf"), isLocal: false, availableTags: &self.availableTags))
        self.documents.append(Document(path: URL(fileURLWithPath: "test/2018/2018-06-22--test-dokument-2__tag1_tag2.pdf"), isLocal: false, availableTags: &self.availableTags))
        self.documents.append(Document(path: URL(fileURLWithPath: "test/2018/2018-12-02--test-dokument-3__tag1_tag2.pdf"), isLocal: false, availableTags: &self.availableTags))
        self.documents.append(Document(path: URL(fileURLWithPath: "test/2018/2018-01-27--test-dokument-4__tag1_tag2.pdf"), isLocal: false, availableTags: &self.availableTags))
        self.documents.append(Document(path: URL(fileURLWithPath: "test/2018/2018-09-19--test-dokument-5__tag1_tag2.pdf"), isLocal: false, availableTags: &self.availableTags))
        self.documents.append(Document(path: URL(fileURLWithPath: "test/2018/2018-08-05--test-dokument-6__tag1_tag2.pdf"), isLocal: false, availableTags: &self.availableTags))
    }
}
