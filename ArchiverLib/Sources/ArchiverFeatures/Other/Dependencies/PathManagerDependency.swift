//
//  PathManagerDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.25.
//

import ArchiverModels
import ArchiverStore
import ComposableArchitecture
import Foundation
import Shared

#warning("TODO: making the PathManager public is inconsistent - it should be internal and only be accessed via ArchiveStore")
@DependencyClient
struct PathManagerDependency: Log {
    var archivePathType: @MainActor @Sendable () -> StorageType = { .iCloudDrive }
//    var setArchivePathType: @Sendable (StorageType) -> Void
}

extension PathManagerDependency: TestDependencyKey {
    static let previewValue = Self(
        archivePathType: { .iCloudDrive },
//        setArchivePathType: { _ in },
    )

    static let testValue = Self()
}

extension PathManagerDependency: DependencyKey {
  static let liveValue = PathManagerDependency(
    archivePathType: { PathManager.shared.archivePathType },
//    setArchivePathType: { type in
//        UserDefaults.archivePathType = type
//    },
  )
}

extension DependencyValues {
  var pathManager: PathManagerDependency {
    get { self[PathManagerDependency.self] }
    set { self[PathManagerDependency.self] = newValue }
  }
}
