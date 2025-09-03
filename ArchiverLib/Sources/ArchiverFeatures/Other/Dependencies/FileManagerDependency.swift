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
    static let previewValue = Self(
        removeItemAt: { _ in },
    )

    static let testValue = Self()
}

extension FileManagerDependency: DependencyKey {
  static let liveValue = FileManagerDependency(
    removeItemAt: { url in
        try FileManager.default.removeItem(at: url)
    }
  )
}

extension DependencyValues {
  var fileManager: FileManagerDependency {
    get { self[FileManagerDependency.self] }
    set { self[FileManagerDependency.self] = newValue }
  }
}
