//
//  UserDefaultsDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.25.
//

import ArchiverModels
import ArchiverStore
import ComposableArchitecture
import Foundation
import Shared

@DependencyClient
struct UserDefaultsDependency: Log {
    var reset: @Sendable () -> Void
}

extension UserDefaultsDependency: TestDependencyKey {
    static let previewValue = Self(
        reset: { },
    )

    static let testValue = Self()
}

extension UserDefaultsDependency: DependencyKey {
    static let liveValue = UserDefaultsDependency(
        reset: {
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
            } else {
                log.error("Bundle Identifier not found.")
            }
        }
    )
}

extension DependencyValues {
    var userDefaultsManager: UserDefaultsDependency {
        get { self[UserDefaultsDependency.self] }
        set { self[UserDefaultsDependency.self] = newValue }
    }
}
