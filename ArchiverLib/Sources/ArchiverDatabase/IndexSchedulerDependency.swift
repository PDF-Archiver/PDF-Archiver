//
//  IndexSchedulerDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import Dependencies
import DependenciesMacros
import Foundation

/// Asks the platform for background time to grow the content index.
///
/// The live values live in `ArchiverFeatures`, because the same runs also drive OCR and the AI
/// cache, which this module must not depend on.
@DependencyClient
public struct IndexSchedulerDependency: Sendable {
    public var schedule: @Sendable () async -> Void
    public var cancel: @Sendable () async -> Void
}

extension IndexSchedulerDependency: TestDependencyKey {
    public static let previewValue = Self(schedule: { }, cancel: { })
    public static let testValue = Self()
}

public extension DependencyValues {
    var indexScheduler: IndexSchedulerDependency {
        get { self[IndexSchedulerDependency.self] }
        set { self[IndexSchedulerDependency.self] = newValue }
    }
}
