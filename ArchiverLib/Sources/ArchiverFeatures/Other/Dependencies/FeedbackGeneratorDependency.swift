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
    static let previewValue = Self(
        notify: { _ in }
    )

    static let testValue = Self()
}

extension FeedbackGeneratorDependency: DependencyKey {
    static let liveValue = FeedbackGeneratorDependency(
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
    )
}

extension DependencyValues {
    var feedbackGenerator: FeedbackGeneratorDependency {
        get { self[FeedbackGeneratorDependency.self] }
        set { self[FeedbackGeneratorDependency.self] = newValue }
    }
}
