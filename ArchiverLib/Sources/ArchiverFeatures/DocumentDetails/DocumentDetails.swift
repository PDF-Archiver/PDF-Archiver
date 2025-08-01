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

    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Action.Alert>?
        @Shared var document: Document
        var documentInformationForm: DocumentInformationForm.State
        var showInspector: Bool

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
                    TextState("You are delete the current document. Are you sure?")
                }
                return .none

            case .onEditButtonTapped:
                if state.showInspector {
                    // reset the inspector state when it should disappear
                    state.documentInformationForm = DocumentInformationForm.State(document: state.document)
                }
                state.showInspector.toggle()
                return .none

            case .onRemoteDocumentAppeared:
                return .run { [documentUrl = state.document.url] _ in
                    try await startDownloadOf(documentUrl)
                }
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
