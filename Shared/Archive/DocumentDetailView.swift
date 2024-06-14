//
//  DocumentDetailView.swift
//  macOS
//
//  Created by Julian Kahnert on 28.03.24.
//

import SwiftData
import SwiftUI
import OSLog

struct DocumentDetailView: View {
    enum ViewState {
        case loading
        case error(any Error)
        case document(Document)
        case documentNotFound
    }
    
    @Binding var documentId: String?
    @Binding var untaggedMode: Bool
    @State private var viewState: ViewState = .documentNotFound
    @State private var showDeleteConfirmation = false
    @Environment(\.modelContext) private var modelContext
    
    #if DEBUG
    let viewStateOverride: ViewState?
    init(documentId: Binding<String?>, untaggedMode: Binding<Bool>, viewStateOverride: ViewState? = nil) {
        self._documentId = documentId
        self._untaggedMode = untaggedMode
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
            let predicate = #Predicate<Document> {
                $0.id == documentId
            }
            var descriptor = FetchDescriptor<Document>(
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
                documentView(for: document)
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
    
    func documentView(for document: Document) -> some View {
        PDFCustomView(document.url)
            .navigationTitle(document.specification)
            .navigationSubtitle(Text(document.date, format: .dateTime.year().month().day()))
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    // editButton
                    Button(action: {
        //                NotificationCenter.default.edit(document: viewModel.document)
                        
                        document.isTagged = false
                        try! document.modelContext?.save()
                        
                        untaggedMode = true
                    }, label: {
                        #if os(macOS)
                        Label("Edit", systemImage: "pencil")
                        #else
                        Label("Edit", systemImage: "pencil")
                            .labelStyle(VerticalLabelStyle())
                        #endif
                    })
                    
                    // showInFinderButton
                    Button(role: .none) {
                        #if os(macOS)
                        NSWorkspace.shared.activateFileViewerSelecting([document.url])
                        #else
                        open(document.url)
                        #endif
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                            #if !os(macOS)
                            .labelStyle(VerticalLabelStyle())
                            #endif
                    }
                    
                    ShareLink(Text(document.filename), item: document.url)
                    
                    // deleteButton
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
                ToolbarItem(placement: .accessoryBar(id: "tags")) {
                    TagListView(tags: document.tags.sorted(), isEditable: false, isMultiLine: false, tapHandler: nil)
                        .font(.caption)
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
}

#if DEBUG
#Preview("Document", traits: .fixedLayout(width: 800, height: 600)) {
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        DocumentDetailView(documentId: .constant("debug-document-id"), untaggedMode: .constant(false), viewStateOverride: nil)
            .modelContainer(previewContainer)
    }
}

#Preview("Loading", traits: .fixedLayout(width: 800, height: 600)) {
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        DocumentDetailView(documentId: .constant(nil), untaggedMode: .constant(false), viewStateOverride: .loading)
            .modelContainer(previewContainer)
    }
}

#Preview("Error", traits: .fixedLayout(width: 800, height: 600)) {
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        DocumentDetailView(documentId: .constant("error"), untaggedMode: .constant(false), viewStateOverride: .error(NSError(domain: "Testing", code: 42)))
            .modelContainer(previewContainer)
    }
}

#Preview("No Document", traits: .fixedLayout(width: 800, height: 600)) {
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        DocumentDetailView(documentId: .constant("1234"), untaggedMode: .constant(false), viewStateOverride: .documentNotFound)
            .modelContainer(previewContainer)
    }
}
#endif
