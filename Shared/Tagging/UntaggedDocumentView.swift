//
//  UntaggedDocumentView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 01.04.24.
//

import SwiftData
import SwiftUI
import OSLog

#warning("TODO: select a new untagged document if the current was saved")
struct UntaggedDocumentView: View {
    @Environment(NavigationModel.self) private var navigationModel
    @Environment(\.modelContext) private var modelContext

    @State private var date = Date()
    @State private var specification = ""
    @State private var tags: [String] = []

    var body: some View {
        if let document = navigationModel.selectedDocument {
            if document.downloadStatus < 1 {
                DocumentLoadingView(filename: document.filename, downloadStatus: document.downloadStatus)
            } else {
                DocumentView(for: document)
                    .navigationTitle(document.specification)
#if os(macOS)
                    .navigationSubtitle(Text(document.date, format: .dateTime.year().month().day()))
#else
                    .navigationBarTitleDisplayMode(.inline)
#endif
            }
        } else {
            ContentUnavailableView("Select a Document", systemImage: "doc", description: Text("Select a document from the list."))
        }
    }

    struct DocumentView: View {
        @Environment(NavigationModel.self) private var navigationModel
        @Environment(\.horizontalSizeClass) var horizontalSizeClass

        let document: Document
        
        @State private var showDeleteConfirmation = false
        @State private var documentInformationViewModel: DocumentInformationViewModel
        
        internal init(for document: Document) {
            self.document = document
            self.documentInformationViewModel = DocumentInformationViewModel(url: document.url)
        }

        var body: some View {
            if horizontalSizeClass == .compact {
                VStack(spacing: 0) {
                    HStack {
                        DeleteDocumentButtonView {
                            Logger.newDocument.debug("Deleting all datapoints, meters and tariffs")
                            do {
                                try FileManager.default.trashItem(at: document.url, resultingItemURL: nil)
                            } catch {
                                Logger.newDocument.errorAndAssert("Error while trashing file \(error)")
                            }
                        }
                        .font(.title)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                        Text(document.specification)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                    
                    pdf
                    DocumentInformation(viewModel: documentInformationViewModel)
                }
            } else {
                HStack {
                    
                    pdf
                    DocumentInformation(viewModel: documentInformationViewModel)
                        .frame(width: 350)
                }
            }
        }

        var pdf: some View {
            PDFCustomView(document.url)
                .toolbar {
                    ToolbarItemGroup(placement: .confirmationAction) {
                        if horizontalSizeClass == .compact {
                            revertButton
                        }
                    }
                    ToolbarItemGroup(placement: .cancellationAction) {
                        if horizontalSizeClass != .compact {
                            revertButton
                            showInFinderButton
                        }
                        DeleteDocumentButtonView {
                            Logger.newDocument.debug("Deleting all datapoints, meters and tariffs")
                            do {
                                try FileManager.default.trashItem(at: document.url, resultingItemURL: nil)
                            } catch {
                                Logger.newDocument.errorAndAssert("Error while trashing file \(error)")
                            }
                        }
                    }
                }
        }

#warning("TODO: implement/fix disabling")
        private var revertButton: some View {
            Button(role: .none) {
                navigationModel.revertDocumentSave()
            } label: {
                Label("Revert", systemImage: "arrow.uturn.backward")
                    #if !os(macOS)
                    .labelStyle(VerticalLabelStyle())
                    #endif
            }
//            .disabled(self.onRevert == nil)
        }

        private var showInFinderButton: some View {
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
        }
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
