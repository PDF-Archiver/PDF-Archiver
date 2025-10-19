//
//  FileManagerDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.25.
//

import ArchiverModels
import ArchiverStore
import ComposableArchitecture
import Foundation

@DependencyClient
struct FileManagerDependency {
    var removeItemAt: @Sendable (URL) throws -> Void
}

extension FileManagerDependency: TestDependencyKey {
    nonisolated(unsafe) static let previewValue: Self = MainActor.assumeIsolated { Self(
        removeItemAt: { _ in },
    ) }

    nonisolated(unsafe) static let testValue: Self = MainActor.assumeIsolated { Self() }
}

extension FileManagerDependency: DependencyKey {
    nonisolated(unsafe) static let liveValue: Self = MainActor.assumeIsolated { FileManagerDependency(
        removeItemAt: { url in
            try FileManager.default.removeItem(at: url)
        }
    ) }
}

extension DependencyValues {
    nonisolated var fileManager: FileManagerDependency {
        get { self[FileManagerDependency.self] }
        set { self[FileManagerDependency.self] = newValue }
    }
}
