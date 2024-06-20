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

    let documentId: String?
    @Binding var untaggedMode: Bool
    @Query private var documents: [Document]
    @State private var showDeleteConfirmation = false
    @Environment(\.modelContext) private var modelContext

    init(documentId: String?, untaggedMode: Binding<Bool>) {
        self.documentId = documentId
        self._untaggedMode = untaggedMode

        var descriptor: FetchDescriptor<Document>
        if let documentId {
            let predicate = #Predicate<Document> { document in
                return document.id == documentId
            }
            descriptor = FetchDescriptor(predicate: predicate)
        } else {
            descriptor = FetchDescriptor<Document>()
        }

        descriptor.fetchLimit = 1
        _documents = Query(descriptor)
    }

    var body: some View {
        if let doc = documents.first {
            if doc.downloadStatus < 1 {
                VStack(spacing: 15) {
                    Spacer()
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 55))
                        .foregroundStyle(.secondary)
                    Text("Downloading Document")
                        .fontWeight(.semibold)
                        .font(.title2)
                    Text("The document will be downloaded to your device. Please wait.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                    ProgressView(doc.filename, value: doc.downloadStatus, total: 1)
                        .progressViewStyle(.linear)
                        .padding(40)
                    Spacer()
                }
                .task {
                    #if DEBUG
                    guard !ProcessInfo().isSwiftUIPreview else { return }
                    #endif
                    await NewArchiveStore.shared.startDownload(of: doc.url)
                }

            } else {
                documentView(for: doc)
            }
        } else {
            ContentUnavailableView("Select a Document", systemImage: "doc", description: Text("Select a document from the list."))
        }
    }

    @ViewBuilder
    func documentView(for document: Document) -> some View {
        PDFCustomView(document.url)
            .navigationTitle(document.specification)

#if os(macOS)
            .navigationSubtitle(Text(document.date, format: .dateTime.year().month().day()))
#else
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    // editButton
                    Button(action: {
                        //                NotificationCenter.default.edit(document: viewModel.document)

                        document.isTagged = false
                        do {
                            try document.modelContext?.save()
                            untaggedMode = true
                        } catch {
                            Logger.archiveStore.error("Failed to save document \(error)")
                            NotificationCenter.default.postAlert(error)
                        }

                    }, label: {
#if os(macOS)
                        Label("Edit", systemImage: "pencil")
#else
                        Label("Edit", systemImage: "pencil")
                            .labelStyle(VerticalLabelStyle())
#endif
                    })

#if os(macOS)
                    // showInFinderButton
                    Button(role: .none) {
                        NSWorkspace.shared.activateFileViewerSelecting([document.url])
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }
#endif

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
#if os(macOS)
                ToolbarItem(placement: .accessoryBar(id: "tags")) {
                    TagListView(tags: document.tags.sorted(), isEditable: false, isMultiLine: false, tapHandler: nil)
                        .font(.caption)
                }
#endif
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
    #if os(iOS)
    NavigationStack {
        DocumentDetailView(documentId: "document-100", untaggedMode: .constant(false))
    }
    .modelContainer(previewContainer(documents: [(id: "document-100", downloadStatus: 1)]))
    #else
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        DocumentDetailView(documentId: "document-100", untaggedMode: .constant(false))
            .modelContainer(previewContainer(documents: [(id: "document-100", downloadStatus: 1)]))
    }
    #endif
}

#Preview("Loading", traits: .fixedLayout(width: 800, height: 600)) {
    #if os(iOS)
    NavigationStack {
        DocumentDetailView(documentId: "document-33", untaggedMode: .constant(false))
    }
    .modelContainer(previewContainer(documents: [(id: "document-33", downloadStatus: 0.33)]))
    #else
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        DocumentDetailView(documentId: "document-33", untaggedMode: .constant(false))
            .modelContainer(previewContainer(documents: [(id: "document-33", downloadStatus: 0.33)]))
    }
    #endif
}

#Preview("Error", traits: .fixedLayout(width: 800, height: 600)) {
    #if os(iOS)
    NavigationStack {
        DocumentDetailView(documentId: "error", untaggedMode: .constant(false))
    }
    .modelContainer(previewContainer())
    #else
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        DocumentDetailView(documentId: "error", untaggedMode: .constant(false))
            .modelContainer(previewContainer())
    }
    #endif
}

#Preview("No Document", traits: .fixedLayout(width: 800, height: 600)) {
    #if os(iOS)
    NavigationStack {
        DocumentDetailView(documentId: "1234", untaggedMode: .constant(false))
    }
    .modelContainer(previewContainer())
    #else
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        DocumentDetailView(documentId: "1234", untaggedMode: .constant(false))
            .modelContainer(previewContainer())
    }
    #endif
}
#endif
