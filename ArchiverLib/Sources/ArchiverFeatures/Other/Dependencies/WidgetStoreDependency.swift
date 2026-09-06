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
    var updateWidget: @Sendable (_ yearCounts: [Int: Int], _ untaggedCount: Int) async -> Void
}

extension WidgetStoreDependency: TestDependencyKey {
    static let previewValue = Self(
        updateWidget: { _, _ in },
    )

    static let testValue = Self()
}

extension WidgetStoreDependency: DependencyKey {
    static let liveValue = WidgetStoreDependency(
        updateWidget: { yearCounts, untaggedCount in
            defer {
                WidgetCenter.shared.reloadAllTimelines()
            }

            await SharedDefaults.set(statistics: yearCounts)
            await SharedDefaults.set(untaggedDocumentsCount: untaggedCount)
        }
    )
}

extension DependencyValues {
    var widgetStore: WidgetStoreDependency {
        get { self[WidgetStoreDependency.self] }
        set { self[WidgetStoreDependency.self] = newValue }
    }
}
