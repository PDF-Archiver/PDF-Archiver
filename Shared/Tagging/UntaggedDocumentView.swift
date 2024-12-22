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

    @State private var document: Document?
    @State private var documentInformationViewModel: DocumentInformation.ViewModel = .init(url: placeholderUrl)

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                VStack(spacing: 0) {
                    if let document {
                        if document.downloadStatus < 1 {
                            DocumentLoadingView(filename: document.filename, downloadStatus: document.downloadStatus)
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
                    if let document {
                        if document.downloadStatus < 1 {
                            DocumentLoadingView(filename: document.filename, downloadStatus: document.downloadStatus)
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
        .onChange(of: navigationModel.selectedDocument, initial: true) { _, newDocument in
            document = newDocument

            if let newDocument {
                documentInformationViewModel = DocumentInformation.ViewModel(url: newDocument.url)
            } else {
                documentInformationViewModel = DocumentInformation.ViewModel(url: Self.placeholderUrl)
            }
        }
        .navigationTitle(document?.filename ?? "")
        #if os(macOS)
        .navigationSubtitle(Text(document?.date ?? Date(), format: .dateTime.year().month().day()))
        #else
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .confirmationAction) {
                if horizontalSizeClass == .compact {
                   deleteButton
                }
            }
            ToolbarItemGroup(placement: .cancellationAction) {
                if horizontalSizeClass != .compact {
                    revertButton
                    showInFinderButton
                }
            }
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
    }

    private var deleteButton: some View {
        DeleteDocumentButtonView {
            Logger.newDocument.debug("Deleting all datapoints, meters and tariffs")
            do {
                guard let document else {
                    assertionFailure("No document selected")
                    return
                }
                try FileManager.default.trashItem(at: document.url, resultingItemURL: nil)
            } catch {
                Logger.newDocument.errorAndAssert("Error while trashing file \(error)")
            }
        }
        .disabled(document == nil)
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
