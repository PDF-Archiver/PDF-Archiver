//
//  WidgetStoreDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.25.
//

import ArchiverModels
import ComposableArchitecture
import Foundation
import Shared
import WidgetKit

@DependencyClient
struct WidgetStoreDependency {
    var updateWidgetWith: @Sendable ([Document]) async -> Void
}

extension WidgetStoreDependency: TestDependencyKey {
    static let previewValue = Self(
        updateWidgetWith: { _ in },
    )

    static let testValue = Self()
}

extension WidgetStoreDependency: DependencyKey {
    static let liveValue = WidgetStoreDependency(
        updateWidgetWith: { documents in
            defer {
                WidgetCenter.shared.reloadAllTimelines()
            }

            // Stats widget
            var statistics: [Int: Int] = [:]
            for document in documents {
                let year = Calendar.current.component(.year, from: document.date)
                statistics[year, default: 0] += 1
            }

            await SharedDefaults.set(statistics: statistics)

            // Untagged documents widget
            let count = documents.filter(\.isTagged.flipped).count
            await SharedDefaults.set(untaggedDocumentsCount: count)
        }
    )
}

extension DependencyValues {
    var widgetStore: WidgetStoreDependency {
        get { self[WidgetStoreDependency.self] }
        set { self[WidgetStoreDependency.self] = newValue }
    }
}
