//
//  Statistics.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 17.07.25.
//

import ArchiverIntents
import ArchiverModels
import ComposableArchitecture
import Shared
import SwiftUI

@Reducer
struct Statistics {
    @ObservableState
    struct State: Equatable {
        @Shared(.documents) var documents: IdentifiedArrayOf<Document> = []

        var isLoading = true
        var yearStats: [Int: Int] = [:]
        var untaggedDocuments = 0
        var totalDocuments = 0
        var totalStorageSize: Double = 0
        var topTags: [TagCount] = []
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
                let documentsArray = Array(documents.elements)

                state.totalDocuments = documentsArray.count
                state.untaggedDocuments = documentsArray.filter { !$0.isTagged }.count
                state.totalStorageSize = documentsArray.reduce(0.0) { $0 + $1.sizeInBytes }

                var yearStats: [Int: Int] = [:]
                for document in documentsArray {
                    let year = Calendar.current.component(.year, from: document.date)
                    yearStats[year, default: 0] += 1
                }
                state.yearStats = yearStats

                var tagCountMap: [String: Int] = [:]
                for tag in documentsArray.flatMap(\.tags) {
                    tagCountMap[tag, default: 0] += 1
                }

                state.topTags = tagCountMap
                    .sorted { lhs, rhs in
                        if lhs.value == rhs.value {
                            lhs.key < rhs.key
                        } else {
                            lhs.value > rhs.value
                        }
                    }
                    .prefix(10)
                    .map { TagCount(tag: $0.key, count: $0.value) }

                state.isLoading = false
                return .none
            }
        }
    }
}

struct StatisticsView: View {
    @Bindable var store: StoreOf<Statistics>

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    StatCard(
                        title: String(localized: "Total Documents", bundle: .module),
                        value: "\(store.totalDocuments)",
                        systemImage: "doc.text.fill"
                    )

                    StatCard(
                        title: String(localized: "Storage", bundle: .module),
                        value: store.totalStorageSize.formattedByteCount,
                        systemImage: "internaldrive.fill"
                    )
                }

                VStack(alignment: .leading, spacing: 24) {
                    StatSection(title: String(localized: "Documents per Year", bundle: .module)) {
                        StatsView(yearStats: store.yearStats, size: .medium)
                    }

                    StatSection(title: String(localized: "Most Used Tags", bundle: .module)) {
                        TopTagsChart(tags: store.topTags)
                    }

                    StatSection(title: String(localized: "Inbox", bundle: .module)) {
                        UntaggedDocumentsView(
                            untaggedDocuments: store.untaggedDocuments,
                            size: .medium
                        )
                    }
                }
            }
            .padding()
        }
        .task {
            await store.send(.onTask).finish()
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            }
        }
    }
}

private struct StatSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            content()
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.paSecondaryBackgroundAsset)
                )
        }
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
