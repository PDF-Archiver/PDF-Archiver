//
//  TagTabViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 02.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import Combine
import PDFKit
import SwiftUI

class TagTabViewModel: ObservableObject {
    @Published var pdfDocument = PDFDocument()
    @Published var date = Date()
    @Published var specification = ""
    @Published var documentTags = [String]()
    @Published var suggestedTags = [String]()

    private let archive: Archive
    private var disposables = Set<AnyCancellable>()

    init(archive: Archive = DocumentService.archive) {
        self.archive = archive

        NotificationCenter.default.publisher(for: .documentChanges)
            .compactMap { _ in
                DocumentService.archive.get(scope: .all, searchterms: [], status: .untagged)
                    .filter { $0.downloadStatus == .local }
                    .max()?.cleaned()
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { document in
                if let pdfDocument = PDFDocument(url: document.path) {
                    self.pdfDocument = pdfDocument

                    // try to parse suggestions from document content
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        // get tags and save them in the background, they will be passed to the TagViewController
                        guard let text = pdfDocument.string else { return }
                        let tags = TagParser.parse(text).sorted()
                        DispatchQueue.main.async {
                            self?.suggestedTags = tags
                        }
                    }
                } else {
                    Log.send(.error, "Could not present document.")
                    self.pdfDocument = PDFDocument()
                }
                self.date = document.date ?? Date()
                self.specification = document.specification
                self.documentTags = Array(document.tags).sorted()
                self.suggestedTags = []
            }
            .store(in: &disposables)
    }
}
