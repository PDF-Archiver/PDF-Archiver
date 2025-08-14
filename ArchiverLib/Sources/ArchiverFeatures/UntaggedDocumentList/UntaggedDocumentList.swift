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
        var untaggedDocuments: IdentifiedArrayOf<Document> { documents.filter(\.isTagged.flipped) }
        @Presents var documentDetails: DocumentDetails.State?
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case documentDetails(PresentationAction<DocumentDetails.Action>)
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
                } else {
                    state.documentDetails = nil
                }
                return .none

            case .binding:
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
            if store.untaggedDocuments.isEmpty {
                ContentUnavailableView("No document", systemImage: "checkmark.seal", description: Text("Congratulations! All documents are tagged. 🎉"))
            } else {
                List(store.untaggedDocuments, selection: $store.selectedDocumentId) { document in
                    Text(document.url.lastPathComponent)
//                    ArchiveListItemView(documentSpecification: document.specification,
//                                        documentDate: document.date,
//                                        documentTags: document.tags.sorted())
                    .tag(document.id)
                }
                #if os(macOS)
                .alternatingRowBackgrounds()
                #endif
            }
        }
        .sensoryFeedback(.selection, trigger: store.selectedDocumentId)
        .navigationDestination(item: $store.scope(state: \.documentDetails, action: \.documentDetails)) { documentStore in
            DocumentDetailsView(store: documentStore)
                .navigationTitle(documentStore.document.specification)
#if os(macOS)
                .navigationSubtitle(Text(documentStore.document.date, format: .dateTime.year().month().day()))
#else
                .navigationBarTitleDisplayMode(.inline)
#endif
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        // editButton
                        Button {
                            documentStore.send(.onEditButtonTapped)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

#if os(macOS)
                        // showInFinderButton
                        Button(role: .none) {
                            NSWorkspace.shared.activateFileViewerSelecting([documentStore.document.url])
                        } label: {
                            Label("Show in Finder", systemImage: "folder")
                        }
#endif

                        // we do not add this button because it has no functionality when the inspector is active
//                        ShareLink(Text(documentStore.document.filename), item: documentStore.document.url)

                        #warning("add this in iOS26")
//                        ToolbarSpacer()

                        // deleteButton
                        Button(role: .destructive) {
                            documentStore.send(.onDeleteDocumentButtonTapped)
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    }
#if os(macOS)
                    ToolbarItem(placement: .accessoryBar(id: "tags")) {
                        TagListView(tags: documentStore.document.tags.sorted(),
                                    isEditable: false,
                                    isMultiLine: false,
                                    tapHandler: nil)
                        .font(.caption)
                    }
#endif
                }
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
