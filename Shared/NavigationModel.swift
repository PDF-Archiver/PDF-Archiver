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
final class NavigationModel {
    private(set) var untaggedMode = false
    
    var selectedTab: TabType = .scan
    
    var selectedDocument: Document?
    
    var lastSavedDocumentId: String?
    
    /// The shared singleton navigation model object.
    static let shared = NavigationModel()
    
    /// Initialize a `NavigationModel` that enables programmatic control of leading columns’
    /// visibility, selected recipe category, and navigation state based on recipe data.
    init() {
    }
    
    func switchToUntaggedMode() {
        selectedDocument = nil
        untaggedMode.toggle()
    }
    
    func saveDocument(_ oldUrl: URL,to filename: String) {
        guard let selectedDocument,
        selectedDocument.url == oldUrl else {
            assertionFailure()
            return
        }
        
        Task {
            do {
                try await NewArchiveStore.shared.archiveFile(from: selectedDocument.url, to: filename)
                
                lastSavedDocumentId = selectedDocument.id
                self.selectedDocument = nil
            } catch {
                Logger.archiveStore.error("Failed to save document \(error)")
                NotificationCenter.default.postAlert(error)
            }
        }
    }
    
    func revertDocumentSave() {
#warning("TODO: Implement revertDocumentSave")
    }
    
    func editDocument() {
        guard let selectedDocument else {
            assertionFailure("No document found that should be edited")
            return
        }
        
        do {
            selectedDocument.isTagged = false
            try selectedDocument.modelContext?.save()
        } catch {
            Logger.archiveStore.error("Failed to save document \(error)")
            assertionFailure("Failed to save document")
        }
    }
    
    func deleteDocument(url: URL) {
        Logger.newDocument.debug("Deleting all datapoints, meters and tariffs")
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        } catch {
            Logger.newDocument.errorAndAssert("Error while trashing file \(error)")
        }
    }
    
    func selectNewUntaggedDocument(in modelContext: ModelContext) {
        guard selectedDocument == nil else { return }

        do {
            let predicate = #Predicate<Document> {
                !$0.isTagged
            }

            var descriptor = FetchDescriptor<Document>(
                predicate: predicate,
                sortBy: [SortDescriptor(\Document.id)]
            )
            descriptor.fetchLimit = 1
            let documents = try modelContext.fetch(descriptor)
            if let document = documents.first,
               document.downloadStatus < 1 {
                print("Start download of document \(document.url.lastPathComponent)")
                Task {
                    await NewArchiveStore.shared.startDownload(of: document.url)
                }
            }
            selectedDocument = documents.first
        } catch {
            selectedDocument = nil
            Logger.newDocument.errorAndAssert("Found error \(error)")
        }
    }
}
