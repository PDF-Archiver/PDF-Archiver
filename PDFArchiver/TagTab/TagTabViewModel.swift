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
    @Published var currentDocument: Document?
    @Published var pdfDocument = PDFDocument()
    @Published var date = Date()
    @Published var specification = ""
    @Published var documentTags = [String]()

    @Published var documentTagInput = ""
    @Published var suggestedTags = [String]()
    @Published var inputAccessoryViewSuggestions = [String]()

    private let archive: Archive
    private var disposables = Set<AnyCancellable>()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let selectionFeedback = UISelectionFeedbackGenerator()

    init(archive: Archive = DocumentService.archive) {
        self.archive = archive

        $documentTagInput
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .removeDuplicates()
            .map { tagName in
                // lowercasing is necessary for sorting!
                let sortedTags = archive.getAvailableTags(with: [tagName])
                    .subtracting(self.currentDocument?.tags ?? [])
                    .subtracting(Set([Constants.documentTagPlaceholder]))
                    .sorted { lhs, rhs in
                        if lhs.starts(with: tagName) {
                            if rhs.starts(with: tagName) {
                                return lhs < rhs
                            } else {
                                return true
                            }
                        } else {
                            if rhs.starts(with: tagName) {
                                return false
                            } else {
                                return lhs < rhs
                            }
                        }
                    }
                return Array(Array(sortedTags).prefix(5))
            }
            .assign(to: \.inputAccessoryViewSuggestions, on: self)
            .store(in: &disposables)

        NotificationCenter.default.publisher(for: .documentChanges)
            .compactMap { _ in
                let documents = DocumentService.archive.get(scope: .all, searchterms: [], status: .untagged)
                guard self.currentDocument == nil || !documents.contains(self.currentDocument!)  else { return nil }
                return documents
                    .filter { $0.downloadStatus == .local }
                    .max()?.cleaned()
            }
            .receive(on: DispatchQueue.main)
            .sink { document in
                self.currentDocument = document
            }
            .store(in: &disposables)

        $currentDocument
            .compactMap { $0 }
            .removeDuplicates()
            .dropFirst()
            .sink { _ in
                self.selectionFeedback.prepare()
                self.selectionFeedback.selectionChanged()
            }
            .store(in: &disposables)

        $currentDocument
            .compactMap { $0 }
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
                            self?.suggestedTags = Array(tags.prefix(12))
                        }
                    }
                } else {
                    Log.send(.error, "Could not present document.")
                    self.pdfDocument = PDFDocument()
                }
                self.date = document.date ?? Date()
                self.specification = document.specification
                self.documentTags = Array(document.tags)
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .sorted()
                self.suggestedTags = []
            }
            .store(in: &disposables)
    }

    func saveTag(_ tagName: String) {
        documentTagInput = ""

        let input = tagName.lowercased().slugified(withSeparator: "")
        guard !input.isEmpty else { return }
        var tags = Set(documentTags)
        tags.insert(input)
        documentTags = Array(tags).sorted()
    }

    func documentTagTapped(_ tagName: String) {
        guard let index = documentTags.firstIndex(of: tagName) else { return }
        documentTags.remove(at: index)

        suggestedTags.append(tagName)
        suggestedTags.sort()

        selectionFeedback.prepare()
        selectionFeedback.selectionChanged()
    }

    func suggestedTagTapped(_ tagName: String) {
        guard let index = suggestedTags.firstIndex(of: tagName) else { return }
        suggestedTags.remove(at: index)

        guard !tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        documentTags.append(tagName)
        documentTags.sort()

        selectionFeedback.prepare()
        selectionFeedback.selectionChanged()
    }

    func saveDocument() {
        guard let document = currentDocument else { return }
        guard let path = StorageHelper.Paths.archivePath else {
            assertionFailure("Could not find a iCloud Drive url.")
            AlertViewModel.createAndPost(title: "Attention",
                                         message: "Could not find iCloud Drive.",
                                         primaryButtonTitle: "OK")
            return
        }

        document.date = date
        document.specification = specification.slugified(withSeparator: "-")
        document.tags = Set(documentTags.map { $0.slugified(withSeparator: "") })

        notificationFeedback.prepare()
        do {
            try document.rename(archivePath: path, slugify: true)
            DocumentService.archive.archive(document)

            currentDocument = nil

            notificationFeedback.notificationOccurred(.success)

            // increment the AppStoreReview counter
            AppStoreReviewRequest.shared.incrementCount()

        } catch {
            Log.send(.error, "Error in PDFProcessing!", extra: ["error": error.localizedDescription])
            AlertViewModel.createAndPost(title: "Delete failed",
                                         message: error,
                                         primaryButtonTitle: "OK")

            notificationFeedback.notificationOccurred(.error)
        }
    }

    func deleteDocument() {

        notificationFeedback.prepare()
        notificationFeedback.notificationOccurred(.success)

        // delete document in archive
        currentDocument?.delete(in: DocumentService.archive)

        // remove the current document and clear the vie
        currentDocument = nil
    }
}
