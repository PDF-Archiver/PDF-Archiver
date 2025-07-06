//
//  ArchiveList.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 03.07.25.
//

import ComposableArchitecture
import SwiftUI
import DomainModels

@Reducer
struct ArchiveList {
    @ObservableState
    struct State: Equatable {
        var documents: IdentifiedArrayOf<Document> = []
        var selectedDocument: Document?
        var documentDetails: DocumentDetails.State? {
            guard let selectedDocument else { return nil }
            return DocumentDetails.State(document: selectedDocument)
        }
    }

    enum Action: BindableAction {
        case tagSearchtermSubmitted
        case documentDetails(DocumentDetails.Action)
        case binding(BindingAction<State>)
    }
    
    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .tagSearchtermSubmitted:
                return .none
            case .documentDetails(_):
                return .none
            case .binding(_):
                return .none
            }
        }
    }
}

struct ArchiveListView: View {
    @Bindable var store: StoreOf<ArchiveList>

    init(store: StoreOf<ArchiveList>) {
        self.store = store
    }

    var body: some View {
        NavigationSplitView {
            List(store.documents, selection: $store.selectedDocument) { document in
                Text(document.url.lastPathComponent)
                    .tag(document)
            }
        } detail: {
            if let childStore = store.scope(state: \.documentDetails, action: \.documentDetails) {
                DocumentDetailsView(store: childStore)
            } else {
                ContentUnavailableView("Select a document", systemImage: "doc", description: Text("Select a document from the list."))
            }
        }
    }
}

#Preview {
    ArchiveListView(
        store: Store(initialState: ArchiveList.State(documents: [
            .mock(url: .temporaryDirectory.appending(component: "file1.pdf")),
            .mock(url: .temporaryDirectory.appending(component: "file2.pdf"), downloadStatus: 1),
        ])) {
            ArchiveList()
                ._printChanges()
        }
    )
}
