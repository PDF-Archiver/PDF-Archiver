//
//  IndexScheduler.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverDatabase
import ArchiverModels
import ComposableArchitecture
import Foundation
import Logging
import Shared
import StoreKit

extension IndexSchedulerDependency: DependencyKey {
    public static let liveValue = IndexSchedulerDependency(
        schedule: {
            // macOS has no `BackgroundTasks` and no launch-on-schedule; `indexWhileAppIsOpen`
            // covers it instead, for as long as the app stays open.
            #if os(iOS)
            BackgroundTaskManager.scheduleCacheProcessing()
            #endif
        },
        cancel: {
            #if os(iOS)
            BackgroundTaskManager.cancelCacheProcessing()
            #endif
        },
        indexWhileAppIsOpen: {
            @Dependency(\.archiveIndexer) var archiveIndexer
            Logger.app.notice("[textindex] Loop started")

            // Both guards below poll, so the reason is logged on change only - a line per round
            // would fill the diagnostics report with the idle case.
            var pauseReason: String?
            var lastProcessingPass: ContinuousClock.Instant?

            while !Task.isCancelled {
                // Not behind the guards below: OCR and the AI cache are free features, and they
                // must keep progressing while the text index waits for premium or for candidates.
                if lastProcessingPass.map({ $0.duration(to: .now) >= processingPassInterval }) ?? true {
                    lastProcessingPass = .now
                    await runProcessingPass()
                }

                let pendingCount = await archiveIndexer.pendingTextCount()
                guard pendingCount > 0 else {
                    Logger.app.debug("[textindex] Loop round", metadata: ["pendingCount": "0"])
                    if pauseReason != "noPendingDocuments" {
                        pauseReason = "noPendingDocuments"
                        // A document that is not on this device is never a candidate, so these two
                        // counts are what tells a finished index from one that cannot reach its files.
                        let counts = await documentCounts()
                        Logger.app.notice("[textindex] Loop paused", metadata: [
                            "reason": "noPendingDocuments",
                            "documentCount": "\(counts.total)",
                            "notDownloadedCount": "\(counts.notDownloaded)"
                        ])
                    }
                    try? await Task.sleep(for: .seconds(60))
                    continue
                }
                let premiumCheckStart = ContinuousClock.now
                let isPremium = await PremiumEntitlement.isActive()
                Logger.app.debug("[textindex] Loop round", metadata: [
                    "pendingCount": "\(pendingCount)",
                    "premium": "\(isPremium)",
                    "premiumCheckMs": "\(premiumCheckStart.duration(to: .now).inMilliseconds)"
                ])
                guard isPremium else {
                    if pauseReason != "noPremium" {
                        pauseReason = "noPremium"
                        Logger.app.notice("[textindex] Loop paused", metadata: ["reason": "noPremium"])
                    }
                    // Long, but not forever: a purchase later in the session starts the index
                    // without asking the user to relaunch.
                    try? await Task.sleep(for: .seconds(300))
                    continue
                }
                if pauseReason != nil {
                    pauseReason = nil
                    Logger.app.notice("[textindex] Loop resumed", metadata: ["pendingCount": "\(pendingCount)"])
                }

                // Ten at a time with a pause between batches: the writer connection is shared with
                // the reconcile, and a foreground pass must never be what the archive list waits on.
                let batchStart = ContinuousClock.now
                let indexed = await archiveIndexer.indexPendingTexts(10)
                Logger.app.debug("[textindex] Batch finished", metadata: [
                    "processedCount": "\(indexed.count)",
                    "durationMs": "\(batchStart.duration(to: .now).inMilliseconds)"
                ])
                await evictLocalCopies(of: indexed)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    )
}

/// How often the open app repeats the OCR and AI-cache pass. Each pass walks every document on
/// this device, so it runs far less often than an index batch - the backfill budgets inside it are
/// what make the repetition worth anything.
private let processingPassInterval: Duration = .seconds(5 * 60)

/// The OCR and AI-cache pass the background task runs, without its downloads: everything already
/// on this device, so a permanently open app is no longer waiting for a night on the charger.
private func runProcessingPass() async {
    @Dependency(\.archiveStore) var archiveStore
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.documentProcessor) var documentProcessor

    let documents = await withErrorReporting {
        try await database.read { db in
            try Document.inbox.fetchAll(db) + Document.aiContext().fetchAll(db)
        }
    }
    guard let documents, !documents.isEmpty else { return }

    let passStart = ContinuousClock.now
    Logger.app.notice("[processing] Foreground pass started", metadata: ["documentCount": "\(documents.count)"])
    let result = await documentProcessor.processUntaggedDocuments(documents)
    Logger.app.notice("[processing] Foreground pass finished", metadata: [
        "documentCount": "\(documents.count)",
        "ocrCount": "\(result.ocrCount)",
        "aiCacheCount": "\(result.aiCacheCount)",
        "durationMs": "\(passStart.duration(to: .now).inMilliseconds)"
    ])

    // An OCR run rewrites the PDF in place, and whether `NSMetadataQuery` reports that for its own
    // process is undocumented, so the rescan is explicit.
    guard result.ocrCount > 0 else { return }
    await withErrorReporting {
        try await archiveStore.reloadDocuments()
    }
}

/// Evicts the local copy of every indexed document outside untagged - the search index is what
/// needed it on this device, and untagged keeps its copy since the inbox prefetch would only fetch
/// it right back. Same switch that mass-downloads the archive (`downloadAllForSearch`) gives it up
/// again; a document the user opened themselves while it is on can also be evicted, and simply
/// re-downloads on next open.
func evictLocalCopies(of documents: [Document]) async {
    @Dependency(\.archiveStore) var archiveStore
    @SharedReader(.archivePathType) var archivePathType: StorageType?
    @Shared(.downloadAllForSearch) var downloadAllForSearch: Bool

    guard downloadAllForSearch, archivePathType == .iCloudDrive else { return }

    var evictedCount = 0
    for document in documents where document.isTagged && document.downloadStatus == 1 {
        let evicted: Void? = await withErrorReporting {
            try await archiveStore.evictDocumentAt(document.url)
        }
        if evicted != nil {
            evictedCount += 1
        }
    }
    Logger.app.debug("[textindex] Evicted local copies", metadata: ["evictedCount": "\(evictedCount)"])
}

/// Runs one step of a background run between `started` and `finished` lines, and marks it as
/// running for the expiration handler, which reports what the run was doing when time ran out.
@discardableResult
func runPhase<Value>(_ name: String,
                     in runningPhases: LockIsolated<Set<String>>,
                     describe: (Value) -> Logger.Metadata = { _ in [:] },
                     operation: () async throws -> Value) async rethrows -> Value {
    runningPhases.withValue { _ = $0.insert(name) }
    let start = ContinuousClock.now
    Logger.backgroundTask.notice("Background phase started", metadata: ["phase": "\(name)"])
    // Left in `runningPhases` when it throws, so the failure report can still name it.
    let value = try await operation()
    runningPhases.withValue { _ = $0.remove(name) }
    var metadata = describe(value)
    metadata["phase"] = "\(name)"
    metadata["durationMs"] = "\(start.duration(to: .now).inMilliseconds)"
    Logger.backgroundTask.notice("Background phase finished", metadata: metadata)
    return value
}

/// What the archive holds versus what of it is reachable, for the paused-loop log line.
private func documentCounts() async -> (total: Int, notDownloaded: Int) {
    @Dependency(\.defaultDatabase) var database
    let counts = await withErrorReporting {
        try await database.read { db in
            (total: try Document.all.fetchCount(db),
             notDownloaded: try Document.where { $0.downloadStatus.lt(1) }.fetchCount(db))
        }
    }
    return counts ?? (total: -1, notDownloaded: -1)
}

/// Whether the content index may grow.
///
/// A cold background launch has no UI, so `@Shared(.premiumStatus)` is still `.loading` there and
/// StoreKit has to be asked directly.
enum PremiumEntitlement {
    static func isActive() async -> Bool {
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified = result else { continue }
            return true
        }
        return false
    }
}
