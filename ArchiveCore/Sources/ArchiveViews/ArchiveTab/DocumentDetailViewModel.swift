//
//  DocumentDetailViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation
import PDFKit

final class DocumentDetailViewModel: ObservableObject {
    let document: Document
    // this will be set lazy when the view has appeared, because we do not
    // want to load all PDFDocument (quite heavy) before we need them
    @Published private(set) var pdfDocument: PDFDocument?
    @Published var pdfDocumentUrl: URL?
    @Published var showActivityView = false
    var activityItems: [Any] {
        [document.path]
    }

    init(_ document: Document) {
        self.document = document
        self.pdfDocumentUrl = document.path
    }

    func viewAppeared() {
        if let url = pdfDocumentUrl {
            pdfDocument = PDFDocument(url: url)
        }
        FeedbackGenerator.selectionChanged()
    }

    func viewDisappeared() {
        // OOM fix: since we save a reference of the view model in a dict, we have to clean up the pdfDocument on disappear
        pdfDocument = nil
    }
}
