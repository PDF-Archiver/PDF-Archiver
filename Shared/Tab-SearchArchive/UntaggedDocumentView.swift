//
//  UntaggedDocumentView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 01.04.24.
//

import SwiftData
import SwiftUI
import OSLog

struct UntaggedDocumentView: View {
    enum ViewState {
        case loading
        case error(Error)
        case document(DBDocument)
        case documentNotFound
    }
    
    @Binding var documentId: String?
    @State private var viewState: ViewState = .documentNotFound
    @Environment(\.modelContext) private var modelContext
    
    @State private var date = Date()
    @State private var specification = ""
    @State private var tags: [String] = []
    
    #if DEBUG
    let viewStateOverride: ViewState?
    init(documentId: Binding<String?>, viewStateOverride: ViewState? = nil) {
        self._documentId = documentId
        self.viewStateOverride = viewStateOverride
    }
    #endif
    
    func update() async {
        #if DEBUG
        if let viewStateOverride {
            viewState = viewStateOverride
            return
        }
        #endif
        viewState = .loading
        do {
            guard let documentId else {
                viewState = .documentNotFound
                return
            }
            let predicate = #Predicate<DBDocument> {
                $0.id == documentId
            }
            var descriptor = FetchDescriptor<DBDocument>(
                predicate: predicate
            )
            descriptor.fetchLimit = 1
            let documents = try modelContext.fetch(descriptor)
            
            if let document = documents.first {
                viewState = .document(document)
            } else {
                viewState = .documentNotFound
            }
        } catch {
            Logger.newDocument.errorAndAssert("Found error")
            viewState = .error(error)
        }
    }

    var body: some View {
        Group {
            switch viewState {
            case .loading:
                ProgressView("Loading document ...")
                    .frame(maxWidth: .infinity)
                    .navigationTitle(" ")
            case .error(let error):
                ErrorView(error: error)
                    .navigationTitle(" ")
            case .document(let document):
                HStack {
                    DocumentView(document: document)
                    DocumentInformation(information: DocumentInformationViewModel(url: document.url))
                        .navigationSplitViewColumnWidth(350)
                }
            case .documentNotFound:
                ContentUnavailableView("Select a Document", systemImage: "doc", description: Text("Select a document from the list."))
            }
        }
        .task {
            await update()
        }
        .onChange(of: documentId) { _, _ in
            Task {
                await update()
            }
        }
    }

    struct DocumentView: View {
        let document: DBDocument
        
        @State private var showDeleteConfirmation = false
        
        var body: some View {
            PDFCustomView(document.url)
                .navigationTitle(document.specification)
                .navigationSubtitle(Text(document.date, format: .dateTime.year().month().day()))
                .toolbar {
                    ToolbarItem(placement: .destructiveAction) {
                        deleteButton
                    }
                }
                .confirmationDialog("Do you really want to delete this document?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        Logger.newDocument.debug("Deleting all datapoints, meters and tariffs")
                        do {
                            try FileManager.default.trashItem(at: document.url, resultingItemURL: nil)
                        } catch {
                            Logger.newDocument.errorAndAssert("Error while trashing file \(error)")
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        withAnimation {
                            showDeleteConfirmation = false
                        }
                    }
                }
        }
        
        private var deleteButton: some View {
            Button(role: .destructive, action: {
                showDeleteConfirmation = true
            }, label: {
                Label("Delete", systemImage: "trash")
                    .foregroundColor(.red)
                    #if !os(macOS)
                    .labelStyle(VerticalLabelStyle())
                    #endif
            })
        }
    }
}

#if DEBUG
#Preview("Document", traits: .fixedLayout(width: 800, height: 600)) {
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        UntaggedDocumentView(documentId: .constant("debug-document-id"), viewStateOverride: nil)
            .modelContainer(previewContainer)
    }
}

#Preview("Loading", traits: .fixedLayout(width: 800, height: 600)) {
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        UntaggedDocumentView(documentId: .constant(nil), viewStateOverride: .loading)
            .modelContainer(previewContainer)
    }
}

#Preview("Error", traits: .fixedLayout(width: 800, height: 600)) {
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        UntaggedDocumentView(documentId: .constant("error"), viewStateOverride: .error(NSError(domain: "Testing", code: 42)))
            .modelContainer(previewContainer)
    }
}

#Preview("No Document", traits: .fixedLayout(width: 800, height: 600)) {
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        UntaggedDocumentView(documentId: .constant("1234"), viewStateOverride: .documentNotFound)
            .modelContainer(previewContainer)
    }
}
#endif
