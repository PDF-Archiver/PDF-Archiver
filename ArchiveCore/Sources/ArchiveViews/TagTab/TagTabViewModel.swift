//
//  TagTabViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 02.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable force_unwrapping function_body_length

import Combine
import PDFKit
import SwiftUI

final class TagTabViewModel: ObservableObject, Log {

    @Published private(set) var error: Error?

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
        let filteredDocuments = documents.filter { $0.taggingStatus == .tagged }
        return "\(filteredDocuments.count) / \(documents.count)"
    }

    private let archiveStore: ArchiveStore
    private let tagStore: TagStore
    private var disposables = Set<AnyCancellable>()

    init(archiveStore: ArchiveStore = ArchiveStore.shared, tagStore: TagStore = TagStore.shared) {
        self.archiveStore = archiveStore
        self.tagStore = tagStore

        // MARK: - Combine Stuff
        archiveStore.$state
            .map { state in
                state == .uninitialized
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.showLoadingView, on: self)
            .store(in: &disposables)

        $documentTagInput
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .map { tagName -> [String] in
                let tags: Set<String>
                if tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    tags = self.getAssociatedTags(from: self.documentTags)
                } else {
                    tags = self.tagStore.getAvailableTags(with: [tagName])
                }

                let sortedTags = tags
                    .subtracting(Set(self.documentTags))
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
                return Array(sortedTags.prefix(5))
            }
            .removeDuplicates()
            .assign(to: &$inputAccessoryViewSuggestions)

        archiveStore.$documents
            .map { newDocuments -> [Document] in
                newDocuments.filter { $0.taggingStatus == .untagged }
            }
            .removeDuplicates()
            .compactMap { newUntaggedDocuments in

                let sortedDocuments = newUntaggedDocuments
                    .sorted { doc1, doc2 in

                        // sort by file creation date to get most recent scans at first
                        if let date1 = try? archiveStore.getCreationDate(of: doc1.path),
                           let date2 = try? archiveStore.getCreationDate(of: doc2.path) {

                            return date1 > date2
                        } else {
                            return doc1 > doc2
                        }
                    }

                // tagged documents should be first in the list
                var currentDocuments = self.documents.filter { $0.taggingStatus == .tagged }
                currentDocuments.append(contentsOf: sortedDocuments)
                DispatchQueue.main.async {
                    self.documents = currentDocuments
                }

                // download new documents
                newUntaggedDocuments
                    .filter { $0.downloadStatus == .remote }
                    .forEach { document in
                        do {
                            try archiveStore.download(document)
                        } catch {
                            DispatchQueue.main.async {
                                self.error = error
                            }
                        }
                    }

                guard self.currentDocument == nil || !newUntaggedDocuments.contains(self.currentDocument!)  else { return nil }

                return self.getNewDocument(from: newUntaggedDocuments)
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
                FeedbackGenerator.selectionChanged()
            }
            .store(in: &disposables)

        $currentDocument
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { document in
                if let document = document,
                   let pdfDocument = PDFDocument(url: document.path) {
                    self.pdfDocument = pdfDocument

                    // try to parse suggestions from document content
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in

                        // get tags and save them in the background, they will be passed to the TagTabView
                        guard let text = pdfDocument.string else { return }
                        let tags = TagParser.parse(text)
                            .subtracting(Set(self?.documentTags ?? []))
                            .sorted()
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

                    self.specification = document.specification
                    self.documentTags = document.tags.sorted()
                    self.suggestedTags = []

                } else {
                    Self.log.error("Could not present document.")
                    self.pdfDocument = PDFDocument()
                    self.specification = ""
                    self.documentTags = []
                    self.suggestedTags = []
                }
            }
            .store(in: &disposables)

        $documentTags
            .removeDuplicates()
            .map { tags -> [String] in
                let tmpTags = tags.map { $0.lowercased().slugified(withSeparator: "") }
                    .filter { !$0.isEmpty }

                FeedbackGenerator.selectionChanged()

                return Set(tmpTags).sorted()
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$documentTags)
//            .assign(to: \.documentTags, on: self)
//            .store(in: &disposables)

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

    func saveDocument() {
        guard let document = currentDocument else { return }

        document.date = date
        document.specification = specification.slugified(withSeparator: "-")
        document.tags = Set(documentTags.map { $0.slugified(withSeparator: "") })

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.archiveStore.archive(document, slugify: true)
                var filteredDocuments = self.archiveStore.documents.filter { $0.id != document.id }
                filteredDocuments.append(document)
                self.archiveStore.documents = filteredDocuments

                DispatchQueue.main.async {
                    self.currentDocument = self.getNewDocument(from: filteredDocuments)
                }

                FeedbackGenerator.notify(.success)

                // increment the AppStoreReview counter
                AppStoreReviewRequest.shared.incrementCount()

            } catch {
                Self.log.error("Error in PDFProcessing!", metadata: ["error": "\(error)"])
                DispatchQueue.main.async {
                    self.error = error
                }

                FeedbackGenerator.notify(.error)
            }
        }
    }

    func deleteDocument() {

        FeedbackGenerator.notify(.success)

        // delete document in archive
        guard let currentDocument = currentDocument else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.archiveStore.delete(currentDocument)

                DispatchQueue.main.async {
                    // delete document from document list
                    self.documents.removeAll { $0.filename == currentDocument.filename }

                    // remove the current document and clear the vie
                    self.currentDocument = self.getNewDocument(from: self.archiveStore.documents)
                }
            } catch {
                Self.log.error("Error while deleting document!", metadata: ["error": "\(error)"])
                DispatchQueue.main.async {
                    self.error = error
                }
            }
        }
    }

    private func getNewDocument(from documents: [Document]) -> Document? {
        documents
            .filter { $0.taggingStatus == .untagged }
            .sorted { $0.filename < $1.filename }
            .first { $0.downloadStatus == .local }
    }

    private func getAssociatedTags(from documentTags: [String]) -> Set<String> {
        guard let firstDocumentTag = documentTags.first?.lowercased() else { return [] }
        var tags = tagStore.getSimilarTags(for: firstDocumentTag)
        for documentTag in documentTags.dropFirst() {

            // enforce that tags is not empty, because all intersection will be also empty otherwise
            guard !tags.isEmpty else { break }

            tags.formIntersection(tagStore.getSimilarTags(for: documentTag.lowercased()))
        }
        return tags
    }
}
