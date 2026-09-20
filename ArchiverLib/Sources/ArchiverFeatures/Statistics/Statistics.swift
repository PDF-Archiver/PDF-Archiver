//
//  Statistics.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 17.07.25.
//

import ArchiverDatabase
import ArchiverIntents
import ArchiverModels
import ComposableArchitecture
import Foundation
import Shared
import SQLiteData
import SwiftUI

@Reducer
struct Statistics {
    /// Every figure the tab shows, in one transaction - they all change together.
    struct Values: Equatable, Sendable {
        var totalDocuments = 0
        var untaggedDocuments = 0
        var totalBytes = 0.0
        var yearStats: [Int: Int] = [:]
        var topTags: [TagCount] = []
    }

    struct Request: FetchKeyRequest {
        /// How many tags the chart shows.
        private static let tagLimit = 10

        func fetch(_ db: Database) throws -> Values {
            let years = try Document.yearCounts(taggedOnly: false).fetchAll(db)
            return Values(
                totalDocuments: try Document.all.fetchCount(db),
                untaggedDocuments: try Document.untaggedCount.fetchOne(db) ?? 0,
                totalBytes: try Document.select { $0.sizeInBytes.sum() }.fetchOne(db).flatMap(\.self) ?? 0,
                yearStats: Dictionary(years.map { ($0.year, $0.count) }, uniquingKeysWith: +),
                topTags: try DocumentTag.counts(limit: Self.tagLimit)
                    .fetchAll(db)
                    .map { TagCount(tag: $0.tag, count: $0.count) }
            )
        }
    }

    @ObservableState
    struct State: Equatable {
        @Fetch(Request()) var stats = Values()

        var totalStorageSize: Measurement<UnitInformationStorage> {
            Measurement(value: stats.totalBytes, unit: .bytes)
        }
    }

    enum Action {
        case onTask
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onTask:
                // The query observes on its own; this only covers a tab opened before the
                // first reconcile has written anything.
                return .run { [stats = state.$stats] _ in
                    await withErrorReporting {
                        try await stats.load()
                    }
                }
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
                        Text(store.stats.totalDocuments, format: .number)
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
                            untaggedDocuments: store.stats.untaggedDocuments,
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
                        StatsView(yearStats: store.stats.yearStats, size: .medium, showActions: false)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.paSecondaryBackgroundAsset)
                            )
                    }

                    Section {
                        TopTagsChart(tags: store.stats.topTags)
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
