//
//  NavigationModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 24.11.24.
//

import SwiftData
import SwiftUI
import OSLog

/// A navigation model used to persist and restore the navigation state.
@Observable
@MainActor
final class NavigationModel {
    enum Mode: Hashable {
        case archive, tagging
    }

    private(set) var mode: Mode = .archive {
        didSet {
            UserDefaults.isTaggingMode = mode == .tagging
        }
    }

    var isScanPresented = false

    var isPreferencesPresented = false

    var selectedDocument: Document?

    var lastSavedDocumentId: Int?

    var premiumStatus: IAP.Status

    var isSubscribedOrLoading: Binding<Bool> {
        Binding(get: {
            self.premiumStatus == .active || self.premiumStatus == .loading
        }, set: { isSubscribed in
            guard !isSubscribed else { return }
            // this will be triggered if a dismiss happend
            self.mode = .archive
            self.selectedDocument = nil
        })
    }

    /// The shared singleton navigation model object.
    static let shared = NavigationModel()

    /// Initialize a `NavigationModel` that enables programmatic control of leading columns’
    /// visibility, selected recipe category, and navigation state based on recipe data.
    private init() {
        mode = UserDefaults.isTaggingMode ? .tagging : .archive
        premiumStatus = .loading
    }

    func switchTaggingMode(in modelContext: ModelContext) {
        selectedDocument = nil

        switch mode {
        case .archive:
            mode = .tagging
            selectNewUntaggedDocument(in: modelContext)
        case .tagging:
            mode = .archive
        }
    }

    func saveDocument(_ oldUrl: URL, to filename: String, modelContext: ModelContext) {
        guard let selectedDocument,
              selectedDocument.url == oldUrl else {
            assertionFailure("The selected document is not the same as the old url - the button should be disabled if no selectedDocument was found")
            return
        }

        Task {
            do {
                let newUrl = try await ArchiveStore.shared.archiveFile(from: oldUrl, to: filename)

                if let id = newUrl.uniqueId() {
                    lastSavedDocumentId = id
                } else {
                    lastSavedDocumentId = nil
                }

                // remove the old document from DB
                modelContext.delete(selectedDocument)
                try modelContext.save()
                self.selectedDocument = nil

                selectNewUntaggedDocument(in: modelContext)
            } catch {
                Logger.navigationModel.error("Failed to save document \(error)")
                NotificationCenter.default.postAlert(error)
            }
        }
    }

    func revertDocumentSave(in modelContext: ModelContext) {
        guard let lastSavedDocumentId else {
            assertionFailure("Failed to get lastSavedDocumentId - the button should be disabled if no lastSavedDocumentId was found")
            return
        }

        Task {
            do {
                selectedDocument = try Document.getBy(id: lastSavedDocumentId, in: modelContext)
                self.lastSavedDocumentId = nil
            } catch {
                self.lastSavedDocumentId = nil
                Logger.navigationModel.errorAndAssert("Found error \(error)")
            }
        }
    }

    func editDocument() {
        guard let selectedDocument else {
            assertionFailure("No document found that should be edited")
            return
        }

        do {
            selectedDocument.isTagged = false
            try selectedDocument.modelContext?.save()

            mode = .tagging
        } catch {
            Logger.navigationModel.errorAndAssert("Failed to save document \(error)")
        }
    }

    func deleteDocument(url: URL) {
        Logger.navigationModel.debug("Deleting all datapoints, meters and tariffs")
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)

            // unselect current document
            self.selectedDocument = nil
        } catch {
            Logger.navigationModel.errorAndAssert("Error while trashing file \(error)")
        }
    }

    func showInFinder() {
        guard let url = selectedDocument?.url else { return }
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #else
        open(url)
        #endif
    }

    func showScan() {
        isScanPresented = true
    }

    #if !os(macOS)
    func showPreferences() {
        isPreferencesPresented = true
    }
    #endif

    private func selectNewUntaggedDocument(in modelContext: ModelContext) {
        do {
            let predicate: Predicate<Document>
            if let selectedDocumentId = selectedDocument?.id {
                predicate = #Predicate<Document> {
                    !$0.isTagged && $0.id != selectedDocumentId
                }
            } else {
                predicate = #Predicate<Document> {
                    !$0.isTagged
                }
            }

            var descriptor = FetchDescriptor<Document>(
                predicate: predicate,
                sortBy: UntaggedDocumentsList.untaggedDocumentSortOrder
            )
            descriptor.fetchLimit = 1
            let documents = try modelContext.fetch(descriptor)
            if let document = documents.first,
               document.downloadStatus < 1 {
                Logger.navigationModel.debug("Start download of document \(document.url.lastPathComponent)")
                Task {
                    await ArchiveStore.shared.startDownload(of: document.url)
                }
            }
            selectedDocument = documents.first
        } catch {
            selectedDocument = nil
            Logger.navigationModel.errorAndAssert("Found error \(error)")
        }
    }
}
