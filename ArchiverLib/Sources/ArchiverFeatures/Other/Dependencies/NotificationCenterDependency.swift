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
        let title: LocalizedStringKey
        let message: LocalizedStringKey
        let primaryButtonTitle: LocalizedStringKey
    }
    var createAndPost: @Sendable (AlertData) -> Void
    var postAlert: @Sendable (Error) -> Void
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
