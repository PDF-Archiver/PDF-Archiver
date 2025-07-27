//
//  Statistics.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 17.07.25.
//

import ArchiverIntents
import ArchiverModels
import ComposableArchitecture
import SwiftUI

@Reducer
struct Statistics {
    @ObservableState
    struct State: Equatable {
        @Shared(.documents) var documents: IdentifiedArrayOf<Document> = []

        var isLoading = true
        var yearStats: [Int: Int] = [:]
        var untaggedDocuments = 0
    }

    enum Action {
        case onTask
        case documentsUpdated(IdentifiedArrayOf<Document>)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onTask:
                return .publisher {
                  state.$documents.publisher
                    .map(Action.documentsUpdated)
                }

            case .documentsUpdated(let documents):
                state.untaggedDocuments = documents.filter(\.isTagged.flipped).count

                var statistics: [Int: Int] = [:]
                for document in documents {
                    let year = Calendar.current.component(.year, from: document.date)
                    statistics[year, default: 0] += 1
                }
                state.yearStats = statistics
                
                #warning("add user defaults saving here? run/trigger action from AppFeature")

                state.isLoading = false
                return .none
            }
        }
    }
}

struct StatisticsView: View {
    @Bindable var store: StoreOf<Statistics>

    var body: some View {
        #warning("fix layout")
        List {
            Section {
                StatsView(yearStats: store.yearStats,
                          size: .medium)
            }

            Section {
                UntaggedDocumentsView(untaggedDocuments: store.untaggedDocuments,
                                      size: .medium)
            }
        }
        .task {
            await store.send(.onTask).finish()
        }
        #warning("add loading spinner")
//        .redacted(reason: store.isLoading ? .invalidated : .privacy)
    }
}

#Preview {
    NavigationStack {
        StatisticsView(
            store: Store(initialState: Statistics.State()) {
                Statistics()
                    ._printChanges()
            }
        )
    }
}
