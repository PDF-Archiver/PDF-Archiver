//
//  TagTabViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 02.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable function_body_length cyclomatic_complexity type_body_length

import Combine
import PDFKit
import SwiftUI

final class TagTabViewModel: ObservableObject, Log {

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

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

    var taggedUntaggedDocuments: String {
        let filteredDocuments = documents.filter { $0.taggingStatus == .tagged }
        return "\(filteredDocuments.count) / \(documents.count)"
    }

    var documentTitle: String? {
        guard let filename = currentDocument?.filename,
           !filename.contains(Constants.documentDatePlaceholder),
           !filename.contains(Constants.documentDescriptionPlaceholder),
           !filename.contains(Constants.documentTagPlaceholder) else { return nil }
        return filename
    }

    var documentSubtitle: String? {
        guard let currentDocument = currentDocument,
              let creationDate = try? archiveStore.getCreationDate(of: currentDocument.path) else { return nil }
        return Self.dateFormatter.string(for: creationDate)
    }

    private let archiveStore: ArchiveStore
    private let tagStore: TagStore
    private var disposables = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "TagTabViewModel", qos: .userInitiated)

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

        $documentTags
            .removeDuplicates()
            .combineLatest($documentTagInput)
            .map { (documentTags, tag) -> [String] in
                let tagName = tag.trimmingCharacters(in: .whitespacesAndNewlines).slugified().lowercased()
                let tags: Set<String>
                if tagName.isEmpty {
                    tags = self.getAssociatedTags(from: documentTags)
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
                return Array(sortedTags.prefix(10))
            }
            .assign(to: &$suggestedTags)

        archiveStore.$documents
            // we have to removeDuplicates before filtering, because if we want to trigger
            // the selection of a new document even if we edit a already tagged document
            .removeDuplicates()
            .map { newDocuments -> [Document] in
                newDocuments.filter { $0.taggingStatus == .untagged }
            }
            .compactMap { newUntaggedDocuments -> [Document] in

                let sortedDocuments = newUntaggedDocuments
                    .sorted { doc1, doc2 in

//                        // sort by file creation date to get most recent scans at first
//                        if let date1 = try? archiveStore.getCreationDate(of: doc1.path),
//                           let date2 = try? archiveStore.getCreationDate(of: doc2.path) {
//
//                            return date1 > date2
//                        } else {
                            return doc1.path.absoluteString > doc2.path.absoluteString
//                        }
                    }
                    .reversed()

                // tagged documents should be first in the list
                var currentDocuments = self.documents.filter { $0.taggingStatus == .tagged }
                    .sorted()
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
                            NotificationCenter.default.postAlert(error)
                        }
                    }

                return currentDocuments
            }
            .receive(on: DispatchQueue.main)
            .sink { currentDocuments in
                if let currentDocument = self.currentDocument,
                   currentDocument.taggingStatus == .untagged,
                   currentDocuments.contains(currentDocument) {
                    // we should not change anything, if a current document was found
                    // and is not tagged yet
                    // and is part of all currentDocuments
                    return
                }
                self.currentDocument = currentDocuments
                    .first { $0.taggingStatus == .untagged && $0.downloadStatus == .local }
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
                    self.specification = document.specification
                    self.documentTags = document.tags.sorted()
                    self.suggestedTags = []

                    // try to parse suggestions from document content
                    self.queue.async { [weak self] in

                        // get the pdf content of first 3 pages
                        var text = ""
                        for index in 0 ..< min(pdfDocument.pageCount, 3) {
                            guard let page = pdfDocument.page(at: index),
                                let pageContent = page.string else { return }

                            text += pageContent
                        }

                        // try to mach some tags from the document and use them as documentTags
                        let matchedTags = tagStore.getTags(from: text)
                        if !matchedTags.isEmpty {
                            DispatchQueue.main.async {
                                self?.documentTags = matchedTags.sorted()
                            }
                        }

                        // get tags and save them in the background, they will be passed to the TagTabView
                        let tags = TagParser.parse(text)
                            .subtracting(Set(self?.documentTags ?? []))
                            .prefix(12)

                        let suggestedTags = Set(tags).union(pdfDocument.getMetadataTags())
                            .sorted()

                        DispatchQueue.main.async {
                            self?.suggestedTags = Array(suggestedTags)
                        }

                        // parse date from document content
                        let documentDate: Date
                        if let date = document.date {
                            documentDate = date
                        } else if let output = DateParser.parse(text) {
                            documentDate = output.date
                            DispatchQueue.main.async {
                                document.date = output.date
                            }
                        } else {
                            documentDate = Date()
                        }
                        DispatchQueue.main.async {
                            self?.date = documentDate
                        }
                    }

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
    }

    func saveTag() {
        let tag = documentTagInput.lowercased().slugified(withSeparator: "")
        guard !tag.isEmpty else { return }
        documentTags.insertAndSort(tag)

        // reset this value after the documents have been set, because the input view
        // tags will be triggered by this and depend on the document tags
        Task.detached {
            await MainActor.run {
                self.documentTagInput = ""
            }
        }
    }

    func suggestedTagTapped(_ tag: String) {
        suggestedTags.removeAll { $0 == tag }
        documentTags.insertAndSort(tag)

        Task.detached {
            await MainActor.run {
                self.documentTagInput = ""
            }
        }
    }

    func documentTagTapped(_ tag: String) {
        documentTags.removeAll { $0 == tag }
//        suggestedTags.insertAndSort(tag)
    }

    func saveDocument() {
        guard let document = currentDocument else { return }

        // slugify the specification first to fix this bug:
        // View was not updating, when the document is already tagged:
        // * save document
        // * change specification
        specification = specification.slugified(withSeparator: "-").lowercased()

        document.date = date
        document.specification = specification
        let slugifiedTags = Set(documentTags.map { $0.slugified(withSeparator: "") })
        document.tags = slugifiedTags

        if !UserDefaults.notSaveDocumentTagsAsPDFMetadata {
            pdfDocument.setMetadataTags(Array(slugifiedTags))
            pdfDocument.write(to: document.path)
        }

        queue.async {
            do {
                try self.archiveStore.archive(document, slugify: true)
                var filteredDocuments = self.archiveStore.documents.filter { $0.id != document.id }
                filteredDocuments.append(document)
                // this will trigger the publisher, which calls getNewDocument, e.g.
                // updates the current document
                self.archiveStore.documents = filteredDocuments

                FeedbackGenerator.notify(.success)

                // increment the AppStoreReview counter
                AppStoreReviewRequest.shared.incrementCount()

            } catch {
                Self.log.error("Error in PDFProcessing!", metadata: ["error": "\(error)"])
                NotificationCenter.default.postAlert(error)

                FeedbackGenerator.notify(.error)
            }
        }
    }

    func deleteDocument() {

        FeedbackGenerator.notify(.success)

        // delete document in archive
        guard let currentDocument = currentDocument else { return }
        queue.async {
            do {
                // this will trigger the publisher, which calls getNewDocument, e.g.
                // updates the current document
                try self.archiveStore.delete(currentDocument)

                DispatchQueue.main.async {
                    // delete document from document list - immediately
                    self.documents.removeAll { $0.filename == currentDocument.filename }
                }
            } catch {
                Self.log.error("Error while deleting document!", metadata: ["error": "\(error)"])
                NotificationCenter.default.postAlert(error)
            }
        }
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
