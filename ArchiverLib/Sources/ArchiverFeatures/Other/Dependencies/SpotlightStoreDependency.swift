//
//  SpotlightStoreDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 19.03.26.
//

import ArchiverModels
import ComposableArchitecture
import CoreSpotlight
import OSLog
import Shared

@DependencyClient
struct SpotlightStoreDependency {
    var updateIndexWith: @Sendable ([Document]) async -> Void
}

extension SpotlightStoreDependency: TestDependencyKey {
    static let previewValue = Self(updateIndexWith: { _ in })
    static let testValue = Self()
}

/// Tracks previously indexed document IDs so we can remove stale entries incrementally.
private actor SpotlightIndexState {
    private var indexedIds: Set<String> = []

    func update(with newIds: Set<String>) -> Set<String> {
        let removed = indexedIds.subtracting(newIds)
        indexedIds = newIds
        return removed
    }
}

extension SpotlightStoreDependency: DependencyKey {
    static let liveValue: SpotlightStoreDependency = {
        let indexState = SpotlightIndexState()
        return SpotlightStoreDependency(
            updateIndexWith: { documents in
                let items = documents.map { document in
                    CSSearchableItem(
                        uniqueIdentifier: "\(document.id)",
                        domainIdentifier: nil,
                        attributeSet: document.searchableAttributes
                    )
                }
                let currentIds = Set(items.map(\.uniqueIdentifier))
                let removedIds = await indexState.update(with: currentIds)
                do {
                    if !removedIds.isEmpty {
                        try await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: Array(removedIds))
                    }
                    try await CSSearchableIndex.default().indexSearchableItems(items)
                    Logger.app.debug("Spotlight index updated with \(items.count) items")
                } catch {
                    Logger.app.error("Failed to update Spotlight index: \(error)")
                }
            }
        )
    }()
}

extension DependencyValues {
    var spotlightStore: SpotlightStoreDependency {
        get { self[SpotlightStoreDependency.self] }
        set { self[SpotlightStoreDependency.self] = newValue }
    }
}
