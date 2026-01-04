//
//  UntaggedDocumentList.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 13.07.25.
//

import ArchiverModels
import ComposableArchitecture
import Shared
import SwiftUI

@Reducer
struct UntaggedDocumentList {
    @ObservableState
    struct State: Equatable {
        @Shared(.documents) var documents: IdentifiedArrayOf<Document> = []
        @Shared(.selectedDocumentId) var selectedDocumentId: Int?
        @Shared(.premiumStatus) var premiumStatus: PremiumStatus = .loading
        var untaggedDocuments: IdentifiedArrayOf<Document> { documents.filter(\.isTagged.flipped) }
        @Presents var documentDetails: DocumentDetails.State?
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case documentDetails(PresentationAction<DocumentDetails.Action>)
        case delegate(Delegate)

        enum Delegate {
            case onCancelIapButtonTapped
        }
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .documentDetails:
                return .none

            case .binding(\.selectedDocumentId):
                if let selectedDocumentId = state.selectedDocumentId,
                   let document = Shared(state.$documents[id: selectedDocumentId]) {
                    state.documentDetails = .init(document: document)
                    return .run { send in
                        await send(.documentDetails(.presented(.updateShowInspector(true))))
                    }
                } else {
                    state.documentDetails = nil
                    return .none
                }

            case .binding:
                return .none

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
            if store.untaggedDocuments.isEmpty {
                ContentUnavailableView(String(localized: "No document", bundle: #bundle),
                                       systemImage: "checkmark.seal",
                                       description: Text("Congratulations! All documents are tagged. 🎉", bundle: #bundle))
            } else {
                List(store.untaggedDocuments, selection: $store.selectedDocumentId) { document in
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
            } else if store.untaggedDocuments.isEmpty {
                ContentUnavailableView(String(localized: "No document", bundle: #bundle),
                                       systemImage: "checkmark.seal",
                                       description: Text("Congratulations! All documents are tagged. 🎉", bundle: #bundle))
            } else {
                List(store.untaggedDocuments, selection: $store.selectedDocumentId) { document in
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
        .navigationDestination(item: $store.scope(state: \.documentDetails, action: \.documentDetails)) { documentStore in
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
