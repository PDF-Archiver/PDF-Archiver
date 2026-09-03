//
//  Statistics.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 17.07.25.
//

import ArchiverIntents
import ArchiverModels
import ComposableArchitecture
import Foundation
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
        var totalStorageSize: Measurement<UnitInformationStorage> = Measurement(value: 0, unit: .bytes)
        var topTags: [TagCount] = []

        /// Derives every figure the tab shows from the archive.
        mutating func apply(documents: IdentifiedArrayOf<Document>) {
            let documentsArray = Array(documents.elements)

            totalDocuments = documentsArray.count
            untaggedDocuments = documentsArray.filter { !$0.isTagged }.count
            let totalBytes = documentsArray.reduce(0.0) { $0 + $1.sizeInBytes }
            totalStorageSize = Measurement(value: totalBytes, unit: .bytes)

            var yearStats: [Int: Int] = [:]
            for document in documentsArray {
                let year = Calendar.current.component(.year, from: document.date)
                yearStats[year, default: 0] += 1
            }
            self.yearStats = yearStats

            var tagCountMap: [String: Int] = [:]
            for tag in documentsArray.flatMap(\.tags) {
                tagCountMap[tag, default: 0] += 1
            }

            topTags = tagCountMap
                .sorted { lhs, rhs in
                    if lhs.value == rhs.value {
                        lhs.key < rhs.key
                    } else {
                        lhs.value > rhs.value
                    }
                }
                .prefix(10)
                .map { TagCount(tag: $0.key, count: $0.value) }

            isLoading = false
        }
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
                state.apply(documents: documents)
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
                        title: String(localized: "Total Documents", bundle: #bundle),
                        systemImage: "doc.text.fill"
                    ) {
                        Text(store.totalDocuments, format: .number)
                    }

                    StatCard(
                        title: String(localized: "Storage", bundle: #bundle),
                        systemImage: "internaldrive.fill"
                    ) {
                        if store.totalStorageSize.value == 0 {
                            Text("0 MB")
                        } else {
                            Text(store.totalStorageSize, format: .byteCount(style: .file, allowedUnits: [.mb, .gb]))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 24) {
                    Section {
                        UntaggedDocumentsStatsView(
                            untaggedDocuments: store.untaggedDocuments,
                            size: .medium,
                            showActions: false
                        )
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.paSecondaryBackgroundAsset)
                        )
                    }

                    Section {
                        StatsView(yearStats: store.yearStats, size: .medium, showActions: false)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.paSecondaryBackgroundAsset)
                            )
                    }

                    Section {
                        TopTagsChart(tags: store.topTags)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.paSecondaryBackgroundAsset)
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
