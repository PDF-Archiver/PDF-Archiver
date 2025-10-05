//
//  StatisticsService.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 04.10.25.
//

import ArchiverModels
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct StatisticsService: Sendable {
    var calculateStatistics: @Sendable ([Document]) async -> CalculatedStatistics = { _ in
        CalculatedStatistics()
    }
}

struct CalculatedStatistics: Equatable, Sendable {
    var totalDocuments = 0
    var untaggedDocuments = 0
    var totalStorageSize: Double = 0
    var yearStats: [Int: Int] = [:]
    var topTags: [TagCount] = []
}

extension StatisticsService: DependencyKey {
    static let liveValue = Self(
        calculateStatistics: { documents in
            await Task.detached(priority: .userInitiated) {
                let totalDocuments = documents.count
                let untaggedDocuments = documents.filter { !$0.isTagged }.count
                let totalStorageSize = documents.reduce(0.0) { $0 + $1.sizeInBytes }

                var yearStats: [Int: Int] = [:]
                for document in documents {
                    let year = Calendar.current.component(.year, from: document.date)
                    yearStats[year, default: 0] += 1
                }

                var tagCountMap: [String: Int] = [:]
                for tag in documents.flatMap(\.tags) {
                    tagCountMap[tag, default: 0] += 1
                }

                let topTags = tagCountMap
                    .sorted { lhs, rhs in
                        if lhs.value == rhs.value {
                            lhs.key < rhs.key
                        } else {
                            lhs.value > rhs.value
                        }
                    }
                    .prefix(10)
                    .map { TagCount(tag: $0.key, count: $0.value) }

                return CalculatedStatistics(
                    totalDocuments: totalDocuments,
                    untaggedDocuments: untaggedDocuments,
                    totalStorageSize: totalStorageSize,
                    yearStats: yearStats,
                    topTags: topTags
                )
            }.value
        }
    )

    static let testValue = Self()
}

extension DependencyValues {
    var statisticsService: StatisticsService {
        get { self[StatisticsService.self] }
        set { self[StatisticsService.self] = newValue }
    }
}
