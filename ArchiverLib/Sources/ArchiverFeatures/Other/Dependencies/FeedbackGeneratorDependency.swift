//
//  FeedbackGeneratorDependency.swift
//  ArchiverLib
//
//  Created by Claude on 11.10.25.
//

import ComposableArchitecture
import Foundation

#if !os(macOS)
import UIKit
#endif

@DependencyClient
struct FeedbackGeneratorDependency {
    enum FeedbackType {
        case success
        case warning
        case error
    }

    var notify: @Sendable (FeedbackType) async -> Void
}

extension FeedbackGeneratorDependency: TestDependencyKey {
    nonisolated(unsafe) static let previewValue: Self = MainActor.assumeIsolated { Self(
        notify: { _ in }
    ) }

    nonisolated(unsafe) static let testValue: Self = MainActor.assumeIsolated { Self() }
}

extension FeedbackGeneratorDependency: DependencyKey {
    nonisolated(unsafe) static let liveValue: Self = MainActor.assumeIsolated { FeedbackGeneratorDependency(
        notify: { feedbackType in
            #if !os(macOS)
            await MainActor.run {
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()

                switch feedbackType {
                case .success:
                    generator.notificationOccurred(.success)
                case .warning:
                    generator.notificationOccurred(.warning)
                case .error:
                    generator.notificationOccurred(.error)
                }
            }
            #endif
        }
    ) }
}

extension DependencyValues {
    nonisolated var feedbackGenerator: FeedbackGeneratorDependency {
        get { self[FeedbackGeneratorDependency.self] }
        set { self[FeedbackGeneratorDependency.self] = newValue }
    }
}
