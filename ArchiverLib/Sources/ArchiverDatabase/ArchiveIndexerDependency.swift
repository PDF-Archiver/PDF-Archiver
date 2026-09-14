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
    public var reconcile: @Sendable ([DocumentInformation], String, Int) async -> Void
    /// `false` if the reconcile is still running when `timeout` is up.
    public var waitWhileReconciling: @Sendable (_ timeout: Duration) async -> Bool = { _ in true }
    public var indexPendingTexts: @Sendable (_ budget: Int) async -> Void
    public var pendingTextCount: @Sendable () async -> Int = { 0 }
    public var requestRebuild: @Sendable () async -> Void
    public var saveSuggestion: @Sendable (_ documentID: Document.ID, _ specification: String, _ tags: [String]) async -> Void
    public var clearSuggestions: @Sendable () async -> Void
    public var saveFeaturePrint: @Sendable (_ documentID: Document.ID, _ encodedObservation: Data, _ revision: Int) async -> Void
    public var clearFeaturePrints: @Sendable () async -> Void
}

extension ArchiveIndexerDependency: TestDependencyKey {
    public static let previewValue = Self(
        setObservedRoots: { _ in 0 },
        reconcile: { _, _, _ in },
        waitWhileReconciling: { _ in true },
        indexPendingTexts: { _ in },
        pendingTextCount: { 0 },
        requestRebuild: { },
        saveSuggestion: { _, _, _ in },
        clearSuggestions: { },
        saveFeaturePrint: { _, _, _ in },
        clearFeaturePrints: { }
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
            },
            waitWhileReconciling: { timeout in
                await indexer.waitWhileReconciling(timeout: timeout)
            },
            indexPendingTexts: { budget in
                await indexer.indexPendingTexts(budget: budget)
            },
            pendingTextCount: {
                await indexer.pendingTextCount()
            },
            requestRebuild: {
                await indexer.requestRebuild()
            },
            saveSuggestion: { documentID, specification, tags in
                await indexer.saveSuggestion(documentID: documentID, specification: specification, tags: tags)
            },
            clearSuggestions: {
                await indexer.clearSuggestions()
            },
            saveFeaturePrint: { documentID, encodedObservation, revision in
                await indexer.saveFeaturePrint(documentID: documentID, encodedObservation: encodedObservation, revision: revision)
            },
            clearFeaturePrints: {
                await indexer.clearFeaturePrints()
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
