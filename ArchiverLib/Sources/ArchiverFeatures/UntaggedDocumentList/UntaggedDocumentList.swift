//
//  UntaggedDocumentList.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 13.07.25.
//

import ArchiverDatabase
import ArchiverModels
import ComposableArchitecture
import Shared
import SQLiteData
import SwiftUI

@Reducer
struct UntaggedDocumentList {
    @ObservableState
    struct State: Equatable {
        @FetchAll(Document.inbox) var documents: [Document]
        @Shared(.selectedDocumentId) var selectedDocumentId: Int?
        @Shared(.premiumStatus) var premiumStatus: PremiumStatus = .loading
        @Presents var documentDetails: DocumentDetails.State?
    }

    enum Action {
        case selectionChanged(Int?)
        case documentDetails(PresentationAction<DocumentDetails.Action>)
        case delegate(Delegate)

        enum Delegate {
            case onCancelIapButtonTapped
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .documentDetails:
                return .none

            case .selectionChanged(let documentId):
                state.$selectedDocumentId.withLock { $0 = documentId }
                guard let documentId,
                      let document = state.documents.first(where: { $0.id == documentId }) else {
                    state.documentDetails = nil
                    return .none
                }
                state.documentDetails = .init(document: document)
                return .run { send in
                    await send(.documentDetails(.presented(.updateShowInspector(true))))
                }

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$documentDetails, action: \.documentDetails) {
            DocumentDetails()
        }
    }
}

struct UntaggedDocumentListView: View {
    @Bindable var store: StoreOf<UntaggedDocumentList>

    var body: some View {
        Group {
            #if os(macOS)
            if store.documents.isEmpty {
                ContentUnavailableView(String(localized: "No document", bundle: #bundle),
                                       systemImage: "checkmark.seal",
                                       description: Text("Congratulations! All documents are tagged. 🎉", bundle: #bundle))
            } else {
                List(store.documents, selection: Binding(get: { store.selectedDocumentId }, set: { store.send(.selectionChanged($0)) })) { document in
                    Text(document.url.lastPathComponent)
                        .tag(document.id)
                }
                .alternatingRowBackgrounds()
            }
            #else
            if store.premiumStatus == .inactive {
                IAPView {
                    store.send(.delegate(.onCancelIapButtonTapped))
                }
            } else if store.documents.isEmpty {
                ContentUnavailableView(String(localized: "No document", bundle: #bundle),
                                       systemImage: "checkmark.seal",
                                       description: Text("Congratulations! All documents are tagged. 🎉", bundle: #bundle))
            } else {
                List(store.documents, selection: Binding(get: { store.selectedDocumentId }, set: { store.send(.selectionChanged($0)) })) { document in
                    Text(document.url.lastPathComponent)
                        .tag(document.id)
                }
            }
            #endif
        }
        #if os(macOS)
        .sheet(isPresented: .init(get: { store.premiumStatus == .inactive }, set: { _ in }), content: {
            IAPView {
                store.send(.delegate(.onCancelIapButtonTapped))
            }
        })
        #endif
        .sensoryFeedback(.selection, trigger: store.selectedDocumentId)
        .navigationDestination(item: $store.scope(\.$documentDetails, action: \.documentDetails)) { documentStore in
            DocumentDetailsView(store: documentStore)
                .navigationTitle(documentStore.document.specification)
#if os(macOS)
                .navigationSubtitle(Text(documentStore.document.date, format: .dateTime.year().month().day()))
#else
                .navigationBarTitleDisplayMode(.inline)
#endif
        }
    }
}

#Preview {
    NavigationStack {
        UntaggedDocumentListView(
            store: Store(initialState: UntaggedDocumentList.State()) {
                UntaggedDocumentList()
                    ._printChanges()
            }
        )
    }
}
