//
//  DocumentDetailView.swift
//  macOS
//
//  Created by Julian Kahnert on 28.03.24.
//

import OSLog
import SwiftData
import SwiftUI

struct DocumentDetailView: View {
    @Environment(NavigationModel.self) private var navigationModel
    @Environment(\.modelContext) private var modelContext
    @State private var document: Document?
    @State private var downloadStatus: Double?

    func update() {
        let document = navigationModel.selectedDocument

        assert(document?.isTagged ?? true, "Document with id \(document?.id ?? 42) is not tagged.")

        // we need to update the document and downloadStatus manual, because changes in document will not trigger a view update
        self.document = document
        self.downloadStatus = document?.downloadStatus
    }

    var body: some View {
        Group {
            if let document,
               let downloadStatus {
                if downloadStatus < 1 {
                    DocumentLoadingView(filename: document.filename, downloadStatus: downloadStatus)
                        .task {
                            #if DEBUG
                            guard !ProcessInfo().isSwiftUIPreview else { return }
                            #endif
                            await ArchiveStore.shared.startDownload(of: document.url)
                        }

                } else {
                    PDFCustomView(document.url)
                        .ignoresSafeArea(edges: .bottom)
                }
            } else {
                ContentUnavailableView("Select a document", systemImage: "doc", description: Text("Select a document from the list."))
            }
        }
        .onChange(of: navigationModel.selectedDocument, initial: true) { _, _ in
            update()
        }
        .task {
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
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // editButton
                Button {
                    navigationModel.editDocument()
                } label: {
                    #if os(macOS)
                    Label("Edit", systemImage: "pencil")
                    #else
                    Label("Edit", systemImage: "pencil")
                        .labelStyle(VerticalLabelStyle())
                    #endif
                }
                .disabled(document == nil)

                if let document {
#if os(macOS)
                    // showInFinderButton
                    Button(role: .none) {
                        NSWorkspace.shared.activateFileViewerSelecting([document.url])
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }
#endif

                    ShareLink(Text(document.filename), item: document.url)
                }

                // deleteButton
                DeleteDocumentButtonView(documentUrl: navigationModel.selectedDocument?.url) { documentUrl in
                    navigationModel.deleteDocument(url: documentUrl, modelContext: modelContext)
                }
            }
#if os(macOS)
            ToolbarItem(placement: .accessoryBar(id: "tags")) {
                TagListView(tags: document?.tags.sorted() ?? [], isEditable: false, isMultiLine: false, tapHandler: nil)
                    .font(.caption)
            }
#endif
        }
        .navigationTitle(document?.specification ?? "")
#if os(macOS)
        .navigationSubtitle(Text(document?.date ?? Date(), format: .dateTime.year().month().day()))
#else
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

#if DEBUG
#Preview("Document", traits: .fixedLayout(width: 800, height: 600)) {
    #if os(iOS)
    NavigationStack {
        DocumentDetailView()
    }
    .modelContainer(previewContainer(documents: [(id: 100, downloadStatus: 1)]))
    #else
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        DocumentDetailView()
            .modelContainer(previewContainer(documents: [(id: 100, downloadStatus: 1)]))
    }
    #endif
}

#Preview("Loading", traits: .fixedLayout(width: 800, height: 600)) {
    #if os(iOS)
    NavigationStack {
        DocumentDetailView()
    }
    .modelContainer(previewContainer(documents: [(id: 33, downloadStatus: 0.33)]))
    #else
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        DocumentDetailView()
            .modelContainer(previewContainer(documents: [(id: 33, downloadStatus: 0.33)]))
    }
    #endif
}

#Preview("Error", traits: .fixedLayout(width: 800, height: 600)) {
    #if os(iOS)
    NavigationStack {
        DocumentDetailView()
    }
    .modelContainer(previewContainer())
    #else
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        DocumentDetailView()
            .modelContainer(previewContainer())
    }
    #endif
}

#Preview("No Document", traits: .fixedLayout(width: 800, height: 600)) {
    #if os(iOS)
    NavigationStack {
        DocumentDetailView()
    }
    .modelContainer(previewContainer())
    #else
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        DocumentDetailView()
            .modelContainer(previewContainer())
    }
    #endif
}
#endif
