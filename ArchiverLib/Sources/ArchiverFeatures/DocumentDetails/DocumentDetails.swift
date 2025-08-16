//
//  DocumentDetails.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 30.06.25.
//

import ArchiverModels
import ComposableArchitecture
import Shared
import SwiftUI

@Reducer
struct DocumentDetails {

    #if os(iOS)
    struct ShareData: Equatable, Identifiable {
        let id: UUID
        let title: String
        let url: URL
    }
    #endif

    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Action.Alert>?
        @Shared var document: Document
        var documentInformationForm: DocumentInformationForm.State
        var showInspector: Bool
        #if os(iOS)
        var shareDocument: ShareData?
        #endif

        init(document: Shared<Document>) {
            self._document = document
            self.documentInformationForm = DocumentInformationForm.State(document: document.wrappedValue)
            self.showInspector = !document.wrappedValue.isTagged
        }
    }

    enum Action: BindableAction, Equatable {
        case alert(PresentationAction<Alert>)
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case onDeleteDocumentButtonTapped
        case onEditButtonTapped
        case onRemoteDocumentAppeared
        #if os(iOS)
        case onShareButtonTapped
        #endif
        case showDocumentInformationForm(DocumentInformationForm.Action)

        enum Alert {
          case confirmDeleteButtonTapped
        }

        enum Delegate: Equatable {
          case deleteDocument(Document)
        }
    }

    @Dependency(\.archiveStore.startDownloadOf) var startDownloadOf
    var body: some ReducerOf<Self> {
        Scope(state: \.documentInformationForm, action: \.showDocumentInformationForm) {
            DocumentInformationForm()
        }

        BindingReducer()
        Reduce { state, action in
            switch action {
            case .alert(.presented(.confirmDeleteButtonTapped)):
                return .send(.delegate(.deleteDocument(state.document)))

            case .alert:
                return .none

            case .binding:
                return .none

            case .delegate:
                return .none

            case .onDeleteDocumentButtonTapped:
                state.alert = AlertState<Action.Alert> {
                    TextState("Delete document?")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDeleteButtonTapped) {
                        TextState("Delete")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("You are deleting the current document. Are you sure?")
                }
                return .none

            case .onEditButtonTapped:
                if state.showInspector {
                    // reset the inspector state when it should disappear
                    state.documentInformationForm = DocumentInformationForm.State(
                        document: state.document)
                    state.showInspector = false
                } else {
                    #if os(iOS)
                    state.shareDocument = nil
                    #endif
                    state.showInspector = true
                }
                return .none

            case .onRemoteDocumentAppeared:
                return .run { [documentUrl = state.document.url] _ in
                    try await startDownloadOf(documentUrl)
                }

            #if os(iOS)
            case .onShareButtonTapped:
                state.showInspector = false
                state.shareDocument = ShareData(
                    id: UUID(),
                    title: state.document.filename,
                    url: state.document.url)
                return .none
            #endif

            case .showDocumentInformationForm:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

struct DocumentDetailsView: View {
    @Bindable var store: StoreOf<DocumentDetails>

    var body: some View {
        Group {
            if store.document.downloadStatus < 1 {
                DocumentLoadingView(filename: store.document.filename, downloadStatus: store.document.downloadStatus)
                    .task {
                        store.send(.onRemoteDocumentAppeared)
                    }

            } else {
                PDFCustomView(store.document.url)
                    .inspector(isPresented: $store.showInspector) {
                        DocumentInformationFormView(store: store.scope(state: \.documentInformationForm, action: \.showDocumentInformationForm))
                    }
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        #if os(iOS)
        .sheet(item: $store.shareDocument) { shareDocument in
            ShareSheet(title: shareDocument.title, url: shareDocument.url)
        }
        #endif
        .toolbar {
            #if os(macOS)
            if store.document.isTagged {
                ToolbarItem(placement: .accessoryBar(id: "tags")) {
                    // macOS Bug: the accessoryBar will trigger a high CPU usage
                    TagListView(
                        tags: store.document.tags.sorted(),
                        isEditable: false,
                        isMultiLine: false,
                        tapHandler: nil
                    )
                    .font(.caption)
                }
            }
            #endif

            ToolbarItemGroup(placement: .primaryAction) {
                // editButton
                Button {
                    store.send(.onEditButtonTapped)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                #if os(macOS)
                    // showInFinderButton
                    Button(role: .none) {
                        NSWorkspace.shared.activateFileViewerSelecting([store.document.url])
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }
                #endif

                // share button
                #if os(iOS)
                Button(role: .none) {
                    store.send(.onShareButtonTapped)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                #else
                // iOS 18 Bug: when the inspector is active/shown, ShareLink will not trigger the share sheet.
                // So we use the workaround with ShareSheet instead.
                ShareLink(Text(store.document.filename), item: store.document.url)
                #endif

                #warning("add this in iOS26")
                // ToolbarSpacer()

                // deleteButton
                Button(role: .destructive) {
                    store.send(.onDeleteDocumentButtonTapped)
                } label: {
                    Label("Delete", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
        }
    }
}

#Preview("Document", traits: .fixedLayout(width: 800, height: 600)) {
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        DocumentDetailsView(
            store: Store(initialState: DocumentDetails.State(document: Shared(value: .mock(downloadStatus: 1)))) {
                DocumentDetails()
                    ._printChanges()
            }
        )
    }
}

#Preview("Loading", traits: .fixedLayout(width: 800, height: 600)) {
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        DocumentDetailsView(
            store: Store(initialState: DocumentDetails.State(document: Shared(value: .mock(downloadStatus: 0.33)))) {
                DocumentDetails()
                    ._printChanges()
            }
        )
    }
}
