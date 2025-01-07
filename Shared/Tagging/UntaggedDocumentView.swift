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
    private static let placeholderUrl = URL.temporaryDirectory

    @Environment(NavigationModel.self) private var navigationModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var documentInformationViewModel: DocumentInformation.ViewModel = .init(url: placeholderUrl)
    @State private var downloadStatus: Double?

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                VStack(spacing: 0) {
                    if let document = navigationModel.selectedDocument {
                        if let downloadStatus,
                           downloadStatus < 1 {
                            DocumentLoadingView(filename: document.filename, downloadStatus: downloadStatus)
                        } else {
                            PDFCustomView(document.url)
                        }
                    } else {
                        ContentUnavailableView("Select a Document", systemImage: "doc", description: Text("Select a document from the list."))
                    }

                    if documentInformationViewModel.url != Self.placeholderUrl {
                        DocumentInformation(viewModel: $documentInformationViewModel)
                    } else {
                        EmptyView()
                    }
                }
            } else {
                HStack {
                    if let document = navigationModel.selectedDocument {
                        if let downloadStatus,
                           downloadStatus < 1 {
                            DocumentLoadingView(filename: document.filename, downloadStatus: downloadStatus)
                        } else {
                            PDFCustomView(document.url)
                        }
                    } else {
                        ContentUnavailableView("Select a Document", systemImage: "doc", description: Text("Select a document from the list."))
                    }

                    Group {
                        if documentInformationViewModel.url != Self.placeholderUrl {
                            DocumentInformation(viewModel: $documentInformationViewModel)
                        } else {
                            EmptyView()
                        }
                    }
                    .frame(width: 350)
                }
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
                      let documentUrl = navigationModel.selectedDocument?.url,
                      urls.contains(documentUrl) else { continue }

                update()
            }
        }
        .onChange(of: navigationModel.selectedDocument, initial: true) { _, newDocument in
            if let newDocument {
                documentInformationViewModel = DocumentInformation.ViewModel(url: newDocument.url)
            } else {
                documentInformationViewModel = DocumentInformation.ViewModel(url: Self.placeholderUrl)
            }
        }
        .navigationTitle(navigationModel.selectedDocument?.filename ?? "")
        #if os(macOS)
        .navigationSubtitle(Text(navigationModel.selectedDocument?.date ?? Date(), format: .dateTime.year().month().day()))
        #else
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(macOS)
            ToolbarItemGroup(placement: .primaryAction) {
                revertButton
                showInFinderButton
                deleteButton
            }
            #else
            
            if horizontalSizeClass == .compact {
                // iOS
                ToolbarItemGroup(placement: .topBarTrailing) {
                    revertButton
                    deleteButton
                }
            } else {
                // iPadOS
                ToolbarItemGroup(placement: .topBarTrailing) {
                    revertButton
                    showInFinderButton
                    deleteButton
                }
            }
            #endif
        }
    }

    private var revertButton: some View {
        Button(role: .none) {
            navigationModel.revertDocumentSave(in: modelContext)
        } label: {
            Label("Revert", systemImage: "arrow.uturn.backward")
                #if !os(macOS)
                .labelStyle(VerticalLabelStyle())
                #endif
        }
        .disabled(navigationModel.lastSavedDocumentId == nil)
    }

    private var showInFinderButton: some View {
        Button(role: .none) {
            navigationModel.showInFinder()
        } label: {
            Label("Show in Finder", systemImage: "folder")
                #if !os(macOS)
                .labelStyle(VerticalLabelStyle())
                #endif
        }
        .disabled(navigationModel.selectedDocument == nil)
    }

    private var deleteButton: some View {
        DeleteDocumentButtonView(documentUrl: navigationModel.selectedDocument?.url) { documentUrl in
            Logger.newDocument.debug("Deleting all datapoints, meters and tariffs")
            do {
                try FileManager.default.trashItem(at: documentUrl, resultingItemURL: nil)
            } catch {
                Logger.newDocument.errorAndAssert("Error while trashing file \(error)")
            }
        }
    }
    
    func update() {
        let document = navigationModel.selectedDocument

        // we need to update the document and downloadStatus manual, because changes in document will not trigger a view update
        self.downloadStatus = document?.downloadStatus
    }
}

#if DEBUG
#Preview("Document", traits: .fixedLayout(width: 800, height: 600)) {
        NavigationSplitView {
            Text("Sidebar")
        } detail: {
            UntaggedDocumentView()
                .modelContainer(previewContainer())
        }
}

#Preview("Document (Stack)", traits: .fixedLayout(width: 800, height: 600)) {
        NavigationStack {
            UntaggedDocumentView()
                .modelContainer(previewContainer())
        }
}
#endif
