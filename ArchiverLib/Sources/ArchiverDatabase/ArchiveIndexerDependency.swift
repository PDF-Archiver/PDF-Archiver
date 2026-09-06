//
//  ArchiveIndexerDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverModels
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct ArchiveIndexerDependency: Sendable {
    public var setObservedRoots: @Sendable ([String]) async -> Int = { _ in 0 }
    public var reconcile: @Sendable ([DocumentSnapshotItem], String, Int) async -> Void
}

extension ArchiveIndexerDependency: TestDependencyKey {
    public static let previewValue = Self(
        setObservedRoots: { _ in 0 },
        reconcile: { _, _, _ in }
    )

    public static let testValue = Self()
}

extension ArchiveIndexerDependency: DependencyKey {
    public static let liveValue: ArchiveIndexerDependency = {
        let indexer = ArchiveIndexer()
        return ArchiveIndexerDependency(
            setObservedRoots: { roots in
                await indexer.setObservedRoots(roots)
            },
            reconcile: { items, root, generation in
                await indexer.reconcile(items, root: root, generation: generation)
            }
        )
    }()
}

public extension DependencyValues {
    var archiveIndexer: ArchiveIndexerDependency {
        get { self[ArchiveIndexerDependency.self] }
        set { self[ArchiveIndexerDependency.self] = newValue }
    }
}
