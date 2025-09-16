//
//  NotificationCenterDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.25.
//

import ArchiverModels
import ArchiverStore
import ComposableArchitecture
import Foundation
import Shared
import SwiftUI

@DependencyClient
struct NotificationCenterDependency: Log {
    struct AlertData {
        let title: LocalizedStringResource
        let message: LocalizedStringResource
        let primaryButtonTitle: LocalizedStringResource
    }
    var createAndPost: @Sendable (AlertData) async -> Void
    var postAlert: @Sendable (Error) async -> Void
}

extension NotificationCenterDependency: TestDependencyKey {
    static let previewValue = Self(
        createAndPost: { _ in },
        postAlert: { _ in },
    )

    static let testValue = Self()
}

extension NotificationCenterDependency: DependencyKey {
    static let liveValue = NotificationCenterDependency(
        createAndPost: { alertData in
            NotificationCenter.default.createAndPost(title: alertData.title,
                                                     message: alertData.message,
                                                     primaryButtonTitle: alertData.primaryButtonTitle)
        },
        postAlert: { error in
            NotificationCenter.default.postAlert(error)
        }
    )
}

extension DependencyValues {
    var notificationCenter: NotificationCenterDependency {
        get { self[NotificationCenterDependency.self] }
        set { self[NotificationCenterDependency.self] = newValue }
    }
}
