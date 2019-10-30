//
//  DocumentDetailViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import Foundation
import PDFKit

class DocumentDetailViewModel: ObservableObject {
    let document: Document

    @Published var pdfDocument: PDFDocument?

    init(_ document: Document) {
        self.document = document
        pdfDocument = PDFDocument(url: document.path)
    }
}
