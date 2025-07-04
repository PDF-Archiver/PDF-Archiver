//
//  DocumentDetails.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 30.06.25.
//

import ComposableArchitecture
import SwiftUI
import DomainModels
import Shared

@Reducer
struct DocumentDetails {
    
    @ObservableState
    struct State: Equatable {
//        var documentInformationForm: DocumentInformationForm.State?
        var document: Document
        var documentInformationForm: DocumentInformationForm.State {
            DocumentInformationForm.State(document: document)
        }
    }

    enum Action: BindableAction {
        case showDocumentInformationFormInspector(DocumentInformationForm.Action)

        case tagSearchtermSubmitted
        
        case binding(BindingAction<State>)
    }
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            #warning("TODO: add this")
            switch action {
            case .binding:
                return .none
            case .tagSearchtermSubmitted:
                return .none
            case .showDocumentInformationFormInspector(_):
                return .none
            }
        }
//        .ifLet(\.documentInformationForm, action: \.showDocumentInformationFormInspector) {
//            DocumentInformationForm()
//        }
    }
}

struct DocumentDetailsView: View {
    @Bindable var store: StoreOf<DocumentDetails>

//    @Environment(NavigationModel.self) private var navigationModel
//    @Environment(\.modelContext) private var modelContext
//    @State private var document: Document?
//    @State private var downloadStatus: Double?

//    func update() {
//        let document = navigationModel.selectedDocument
//
//        assert(document?.isTagged ?? true, "Document with id \(document?.id ?? 42) is not tagged.")
//
//        // we need to update the document and downloadStatus manual, because changes in document will not trigger a view update
//        self.document = document
//        self.downloadStatus = document?.downloadStatus
//    }

    var body: some View {
        Group {
//            if let document = store.document {
            if store.document.downloadStatus < 1 {
                DocumentLoadingView(filename: store.document.filename, downloadStatus: store.document.downloadStatus)
                    .task {
#warning("TODO: add this")
                        //                            #if DEBUG
                        //                            guard !ProcessInfo().isSwiftUIPreview else { return }
                        //                            #endif
                        //                            await ArchiveStore.shared.startDownload(of: document.url)
                    }
                
            } else {
                PDFCustomView(store.document.url)
                    .ignoresSafeArea(edges: .bottom)
                    .inspector(isPresented: .constant(true)) {
                        DocumentInformationFormView(store: store.scope(state: \.documentInformationForm, action: \.showDocumentInformationFormInspector))
                    }
            }
        }
//        .onChange(of: navigationModel.selectedDocument, initial: true) { _, _ in
//            #warning("TODO: add this")
////            update()
//        }
        .task {
            #warning("TODO: add this")
            // Currently we need to update this view on changes in Document, because it will not be triggered via SwiftData changes automatically.
            // Example use case: select a document that will be downloaded and the download status changes
//            let changeUrlStream = NotificationCenter.default.notifications(named: .documentUpdate)
//            for await notification in changeUrlStream {
//                guard let urls = notification.object as? [URL],
//                      let documentUrl = document?.url,
//                      urls.contains(documentUrl) else { continue }
//
//                update()
//            }
        }
//        .toolbar {
//#warning("TODO: move these to upper level")
//            ToolbarItemGroup(placement: .primaryAction) {
//                // editButton
//                Button {
//                    #warning("TODO: add this")
////                    navigationModel.editDocument()
//                } label: {
//                    #if os(macOS)
//                    Label("Edit", systemImage: "pencil")
//                    #else
//                    Label("Edit", systemImage: "pencil")
//                        .labelStyle(VerticalLabelStyle())
//                    #endif
//                }
//                .disabled(store.document == nil)
//
//                if let document = store.document {
//#if os(macOS)
//                    // showInFinderButton
//                    Button(role: .none) {
//                        NSWorkspace.shared.activateFileViewerSelecting([document.url])
//                    } label: {
//                        Label("Show in Finder", systemImage: "folder")
//                    }
//#endif
//
//                    ShareLink(Text(document.filename), item: document.url)
//                }
//
//                // deleteButton
//                DeleteDocumentButtonView(documentUrl: store.document?.url) { documentUrl in
//                    
//                    #warning("TODO: add this")
////                    navigationModel.deleteDocument(url: documentUrl, modelContext: modelContext)
//                }
//            }
//#if os(macOS)
//            ToolbarItem(placement: .accessoryBar(id: "tags")) {
//                TagListView(tags: store.document?.tags.sorted() ?? [], isEditable: false, isMultiLine: false, tapHandler: nil)
//                    .font(.caption)
//            }
//#endif
//        }
//        .navigationTitle(store.document?.specification ?? "")
//#if os(macOS)
//        .navigationSubtitle(Text(store.document?.date ?? Date(), format: .dateTime.year().month().day()))
//#else
//        .navigationBarTitleDisplayMode(.inline)
//#endif
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
        DocumentDetailsView(
            store: Store(initialState: DocumentDetails.State(document: .mock(downloadStatus: 1))) {
                DocumentDetails()
                    ._printChanges()
            }
        )
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
        DocumentDetailsView(
            store: Store(initialState: DocumentDetails.State(document: .mock(downloadStatus: 0.33))) {
                DocumentDetails()
                    ._printChanges()
            }
        )
    }
    #endif
}
#endif
