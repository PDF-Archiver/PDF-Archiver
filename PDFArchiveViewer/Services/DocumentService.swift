//
//  ArchiveService.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 18.02.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import Foundation

/// Singleton responsible for accessing and searching documents.
final class DocumentService {

    static let archive = Archive()

    static let documentsQuery: DocumentsQuery = {
        let query = DocumentsQuery()
        // setup data delegate
        query.documentsQueryDelegate = DocumentService.archive
        return query
    }()
}
