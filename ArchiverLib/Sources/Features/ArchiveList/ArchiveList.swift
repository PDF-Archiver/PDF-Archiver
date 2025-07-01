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
    struct State {
        var documents: IdentifiedArrayOf<Document> = []
        var selectedDocument: Document?
    }
    enum Action {
        case tagSearchtermSubmitted
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .tagSearchtermSubmitted:
                return .none
            }
        }
    }
}

struct ArchiveListView: View {
    @Bindable var store: StoreOf<ArchiveList>

    var body: some View {
        List(Array(store.documents)) { document in
            Text(document.url.path())
            
        }
    }
}

#Preview {
    ArchiveListView(
        store: Store(initialState: ArchiveList.State(documents: [
            .mock(url: .temporaryDirectory.appending(component: "file1.pdf")),
            .mock(url: .temporaryDirectory.appending(component: "file2.pdf")),
        ])) {
            ArchiveList()
                ._printChanges()
        }
    )
}
