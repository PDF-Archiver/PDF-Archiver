//
//  TagTabViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 02.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable force_unwrapping function_body_length

import ArchiveLib
import Combine
import PDFKit
import SwiftUI

class TagTabViewModel: ObservableObject {

    // set this property manually
    @Published var documents = [Document]()
    @Published var currentDocument: Document?

    @Published var showLoadingView = true

    // there properties will be set be some combine actions
    @Published var pdfDocument = PDFDocument()
    @Published var date = Date()
    @Published var specification = ""
    @Published var documentTags = [String]()
    @Published var documentTagInput = ""
    @Published var suggestedTags = [String]()
    @Published var inputAccessoryViewSuggestions = [String]()

    var taggedUntaggedDocuments: String {
        "\(documents.filter({$0.taggingStatus == .tagged}).count) / \(documents.count)"
    }

    private let archive: Archive
    private var disposables = Set<AnyCancellable>()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let selectionFeedback = UISelectionFeedbackGenerator()

    init(archive: Archive = DocumentService.archive) {
        self.archive = archive

        // MARK: - Combine Stuff
        NotificationCenter.default.publisher(for: .documentChanges)
            .receive(on: DispatchQueue.main)
            .map { _ in false }
            .assign(to: \.showLoadingView, on: self)
            .store(in: &disposables)

        // we assume that all documents should be loaded after 10 seconds
        // force the disappear of the loading view
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10)) {
            self.showLoadingView = false
        }

        $documentTagInput
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .map { tagName -> [String] in
                let tags: Set<String>
                if tagName.isEmpty {
                    tags = self.getAssociatedTags(from: self.documentTags)
                } else {
                    tags = self.archive.getAvailableTags(with: [tagName])
                }

                let sortedTags = tags
                    .subtracting(self.currentDocument?.tags ?? [])
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
                return Array(sortedTags.prefix(5))
            }
            .removeDuplicates()
            .assign(to: \.inputAccessoryViewSuggestions, on: self)
            .store(in: &disposables)

        NotificationCenter.default.publisher(for: .documentChanges)
            .map { _ in
                DocumentService.archive.get(scope: .all, searchterms: [], status: .untagged)
            }
            .removeDuplicates()
            .compactMap { newUntaggedDocuments in

                // save new documents
                var currentDocuments = self.documents.filter { $0.taggingStatus == .tagged }
                currentDocuments.append(contentsOf: newUntaggedDocuments.sorted(by: { $0.filename < $1.filename }))
                DispatchQueue.main.async {
                    self.documents = currentDocuments
                }

                // download new documents
                newUntaggedDocuments
                    .filter { $0.downloadStatus == .iCloudDrive }
                    .forEach { $0.download() }

                guard self.currentDocument == nil || !newUntaggedDocuments.contains(self.currentDocument!)  else { return nil }

                return self.getNewDocument()
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
            .compactMap { $0?.cleaned() }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { document in
                if let pdfDocument = PDFDocument(url: document.path) {
                    self.pdfDocument = pdfDocument

                    // try to parse suggestions from document content
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        // get tags and save them in the background, they will be passed to the TagTabView
                        guard let text = pdfDocument.string else { return }
                        let tags = TagParser.parse(text).sorted()
                        DispatchQueue.main.async {
                            self?.suggestedTags = Array(tags.prefix(12))
                        }

                        // parse date from document content
                        let documentDate: Date
                        if let date = document.date {
                            documentDate = date
                        } else if let output = DateParser.parse(text) {
                            documentDate = output.date
                        } else {
                            documentDate = Date()
                        }
                        DispatchQueue.main.async {
                            self?.date = documentDate
                        }
                    }

                } else {
                    Log.send(.error, "Could not present document.")
                    self.pdfDocument = PDFDocument()
                    assertionFailure("Could not present document.")
                }
                self.specification = document.specification
                self.documentTags = document.tags.sorted()
                self.suggestedTags = []
            }
            .store(in: &disposables)
    }

    func saveTag(_ tagName: String) {
        // reset this value after the documents have been set, because the input view
        // tags will be triggered by this and depend on the document tags
        defer {
            documentTagInput = ""
        }

        let input = tagName.lowercased().slugified(withSeparator: "")
        guard !input.isEmpty else { return }
        var tags = Set(documentTags)
        tags.insert(input)
        documentTags = Array(tags).sorted()
    }

    func documentTagTapped(_ tagName: String) {
        guard let index = documentTags.firstIndex(of: tagName) else { return }
        documentTags.remove(at: index)

        let newTags = Set(suggestedTags).union([tagName])
        suggestedTags = Array(newTags).sorted()

        selectionFeedback.prepare()
        selectionFeedback.selectionChanged()
    }

    func suggestedTagTapped(_ tagName: String) {
        guard let index = suggestedTags.firstIndex(of: tagName) else { return }
        suggestedTags.remove(at: index)

        saveTag(tagName)

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

            currentDocument = getNewDocument()

            notificationFeedback.notificationOccurred(.success)

            // increment the AppStoreReview counter
            AppStoreReviewRequest.shared.incrementCount()

        } catch {
            Log.send(.error, "Error in PDFProcessing!", extra: ["error": error.localizedDescription])
            AlertViewModel.createAndPost(title: "Save failed!",
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

        // delete document from document list
        documents.removeAll { $0.filename == currentDocument?.filename }

        // remove the current document and clear the vie
        currentDocument = getNewDocument()
    }

    private func getNewDocument() -> Document? {
        DocumentService.archive.get(scope: .all, searchterms: [], status: .untagged)
            .sorted { $0.filename < $1.filename }
            .first { $0.downloadStatus == .local }
    }

    private func getAssociatedTags(from documentTags: [String]) -> Set<String> {
        guard let firstDocumentTag = documentTags.first?.lowercased() else { return [] }
        var tags = archive.getSimilarTags(for: firstDocumentTag)
        for documentTag in documentTags.dropFirst() {

            // enforce that tags is not empty, because all intersection will be also empty otherwise
            guard !tags.isEmpty else { break }

            tags.formIntersection(archive.getSimilarTags(for: documentTag.lowercased()))
        }
        return tags
    }
}
