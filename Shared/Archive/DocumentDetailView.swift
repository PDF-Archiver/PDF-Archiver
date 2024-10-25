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
    @Binding var documentId: String?
    @Binding var untaggedMode: Bool
    @State private var document: Document?
    @State private var downloadStatus: Double?

    @State private var showDeleteConfirmation = false
    @Environment(\.modelContext) private var modelContext

    init(documentId: Binding<String?>, untaggedMode: Binding<Bool>) {
        self._documentId = documentId
        self._untaggedMode = untaggedMode
    }

    func update() {
        guard let documentId else {
            document = nil
            downloadStatus = nil
            return
        }
        let predicate = #Predicate<Document> { document in
            return document.id == documentId
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        do {
            let document = (try modelContext.fetch(descriptor)).first

            assert(document?.isTagged ?? true, "Document with id \(documentId) is not tagged.")

            // we need to update the document and downloadStatus manual, because changes in document will not trigger a view update
            self.document = document
            self.downloadStatus = document?.downloadStatus
        } catch {
            assertionFailure("Failed to fetch document: \(error.localizedDescription)")
        }
    }

    var body: some View {
        content
            .onChange(of: documentId, { _, _ in
                update()
            })
            .task {
                update()

                // Currently we need to update this view on changes in Document, because it will not be triggered via SwiftData changes automatically.
                // Example use case: select a document that will be downloaded and the download status changes
                let changeUrlStream = NotificationCenter.default.notifications(named: .documentUpdate)
                for await notification in changeUrlStream {
                    guard let urls = notification.object as? [URL],
                          let documentUrl = document?.url,
                          urls.contains(documentUrl) else { continue }

                    update()
                }
            }
    }

    @ViewBuilder
    var content: some View {
        if let document,
           let downloadStatus {
            if downloadStatus < 1 {
                DocumentLoadingView(filename: document.filename, downloadStatus: downloadStatus)
                    .task {
                        #if DEBUG
                        guard !ProcessInfo().isSwiftUIPreview else { return }
                        #endif
                        await NewArchiveStore.shared.startDownload(of: document.url)
                    }

            } else {
                documentView(for: document)
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
        DocumentDetailView(documentId: .constant("document-100"), untaggedMode: .constant(false))
    }
    .modelContainer(previewContainer(documents: [(id: "document-100", downloadStatus: 1)]))
    #else
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        DocumentDetailView(documentId: .constant("document-100"), untaggedMode: .constant(false))
            .modelContainer(previewContainer(documents: [(id: "document-100", downloadStatus: 1)]))
    }
    #endif
}

#Preview("Loading", traits: .fixedLayout(width: 800, height: 600)) {
    #if os(iOS)
    NavigationStack {
        DocumentDetailView(documentId: .constant("document-33"), untaggedMode: .constant(false))
    }
    .modelContainer(previewContainer(documents: [(id: "document-33", downloadStatus: 0.33)]))
    #else
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        DocumentDetailView(documentId: .constant("document-33"), untaggedMode: .constant(false))
            .modelContainer(previewContainer(documents: [(id: "document-33", downloadStatus: 0.33)]))
    }
    #endif
}

#Preview("Error", traits: .fixedLayout(width: 800, height: 600)) {
    #if os(iOS)
    NavigationStack {
        DocumentDetailView(documentId: .constant("error"), untaggedMode: .constant(false))
    }
    .modelContainer(previewContainer())
    #else
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        DocumentDetailView(documentId: .constant("error"), untaggedMode: .constant(false))
            .modelContainer(previewContainer())
    }
    #endif
}

#Preview("No Document", traits: .fixedLayout(width: 800, height: 600)) {
    #if os(iOS)
    NavigationStack {
        DocumentDetailView(documentId: .constant("1234"), untaggedMode: .constant(false))
    }
    .modelContainer(previewContainer())
    #else
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        DocumentDetailView(documentId: .constant("1234"), untaggedMode: .constant(false))
            .modelContainer(previewContainer())
    }
    #endif
}
#endif
