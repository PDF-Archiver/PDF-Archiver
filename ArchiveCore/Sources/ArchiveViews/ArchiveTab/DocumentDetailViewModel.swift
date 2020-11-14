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
    @Published var pdfDocument: PDFDocument?
    @Published var showActivityView: Bool = false
    var activityItems: [Any] {
        [document.path]
    }

    init(_ document: Document) {
        self.document = document
        pdfDocument = PDFDocument(url: document.path)
    }

    func viewAppeared() {
        FeedbackGenerator.selectionChanged()
    }
}
