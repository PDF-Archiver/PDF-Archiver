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

    private let archive: Archive
    private var disposables = Set<AnyCancellable>()

    init(archive: Archive = DocumentService.archive) {
        self.archive = archive

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
                self.documentTags = Array(document.tags).sorted()
                self.suggestedTags = []
            }
            .store(in: &disposables)
    }

    func saveTag() {
        let input = documentTagInput.lowercased().slugified(withSeparator: "")
        documentTagInput = ""
        guard !input.isEmpty else { return }
        var tags = documentTags
        tags.append(input)
        documentTags = tags.sorted()
    }

    func documentTagTapped(_ tagName: String) {
        guard let index = documentTags.firstIndex(of: tagName) else { return }
        documentTags.remove(at: index)

        suggestedTags.append(tagName)
        suggestedTags.sort()
    }

    func suggestedTagTapped(_ tagName: String) {
        guard let index = suggestedTags.firstIndex(of: tagName) else { return }
        suggestedTags.remove(at: index)

        documentTags.append(tagName)
        documentTags.sort()
    }

    func saveDocument() {
        guard let document = currentDocument else { return }
        guard let path = StorageHelper.Paths.archivePath else {
            assertionFailure("Could not find a iCloud Drive url.")
            // TODO: handle error
//            present(StorageHelper.Paths.iCloudDriveAlertController, animated: true, completion: nil)
            return
        }

        document.date = date
        document.specification = specification.slugified(withSeparator: "-")
        document.tags = Set(documentTags.map { $0.slugified(withSeparator: "") })

        do {
            try document.rename(archivePath: path, slugify: true)
            DocumentService.archive.archive(document)

            currentDocument = nil

            // increment the AppStoreReview counter
            AppStoreReviewRequest.shared.incrementCount()

            // TODO: handle error
//        } catch let error as LocalizedError {
//            os_log("Error occurred while renaming Document: %@", log: DocumentHandleViewController.log, type: .error, error.localizedDescription)
//
//            // OK button will be created by the convenience initializer
//            let alertController = UIAlertController(error, preferredStyle: .alert)
//            present(alertController, animated: true, completion: nil)
//            notificationFeedback.notificationOccurred(.error)
        } catch {
//            os_log("Error occurred while renaming Document: %@", log: DocumentHandleViewController.log, type: .error, error.localizedDescription)
//            let alertController = UIAlertController(title: NSLocalizedString("error_message_fallback", comment: "Fallback when no localized error was found."), message: error.localizedDescription, preferredStyle: .alert)
//            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Button confirmation label"), style: .default, handler: nil))
//            present(alertController, animated: true, completion: nil)
//            notificationFeedback.notificationOccurred(.error)
        }
    }

    func deleteDocument() {
        currentDocument?.delete(in: DocumentService.archive)
    }
}
