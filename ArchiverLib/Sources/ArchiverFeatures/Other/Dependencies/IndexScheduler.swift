//
//  IndexScheduler.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverDatabase
import ArchiverModels
import ComposableArchitecture
import DocumentProcessingPipeline
import Foundation
import Logging
import Shared

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
            Logger.app.notice("[textindex] Loop started")
            // Independent children: the processing pass has no budget, and one that runs for
            // hours must not hold the text index back.
            await withDiscardingTaskGroup { group in
                group.addTask {
                    await processWhileAppIsOpen()
                }
                group.addTask {
                    await indexTextsWhileAppIsOpen()
                }
            }
        }
    )
}

/// Not behind the text index's guards: OCR and the AI cache are free features, and they must keep
/// progressing while the text index waits for premium or for candidates.
private func processWhileAppIsOpen() async {
    while !Task.isCancelled {
        await runProcessingPass()
        // From the end of a pass: counted from its start, a long pass was followed by the next
        // one at once.
        try? await Task.sleep(for: processingPassInterval)
    }
}

private func indexTextsWhileAppIsOpen() async {
    @Dependency(\.archiveIndexer) var archiveIndexer

    // Both guards below poll, so the reason is logged on change only - a line per round
    // would fill the diagnostics report with the idle case.
    var pauseReason: String?

    while !Task.isCancelled {
        let pendingCount = await archiveIndexer.pendingTextCount()
        guard pendingCount > 0 else {
            // TODO: Remove with the diagnostic logs (#339).
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
        // TODO: Remove the timing and the `Loop round` line with the diagnostic logs (#339).
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
        // TODO: Remove the timing and the `Batch finished` line with the diagnostic logs (#339).
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

    // TODO: Remove the start line and `durationMs` with the diagnostic logs (#339).
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

/// Documents per background run, matched to `SearchIndexDownloads.batchSize` so extraction does not
/// fall behind the downloads. An expiring task cancels the run and leaves the rest pending.
private let backgroundIndexBudget = 250

/// How long a cold start may take before the run gives up on the metadata. The iCloud metadata
/// gather of a 3.000-document archive needs about half a minute, a first download far longer.
private let initialLoadTimeout = Duration.seconds(5 * 60)

/// The work of one background run, without the `BGProcessingTask` around it. Returns the pass
/// result the completion notification reports.
func runBackgroundProcessing(runningPhases: LockIsolated<Set<String>>) async throws -> UntaggedProcessingResult {
    @Dependency(\.archiveStore) var archiveStore
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.documentProcessor) var documentProcessor

    // A cold background launch has no scene, so nothing else starts the folder scan, and
    // the wait below gives that scan the writer connection before the text pass takes it.
    try await runPhase("reload", in: runningPhases) {
        try await archiveStore.reloadDocuments()
    }
    await runPhase("initialLoadWait", in: runningPhases, describe: { ["reconciled": "\($0)"] }, operation: {
        await waitForInitialDocumentLoad()
    })

    let isPremium = await runPhase("premium", in: runningPhases, describe: { ["premium": "\($0)"] }, operation: {
        await PremiumEntitlement.isActive()
    })
    if isPremium {
        await runPhase("prefetch", in: runningPhases) {
            await SearchIndexDownloads.requestNextBatch()
        }
    }

    let documents = try await database.read { db in
        try Document.inbox.fetchAll(db) + Document.aiContext().fetchAll(db)
    }
    // Side by side: the processing pass has no budget, and the text pass must not wait for it.
    async let textPass: Void = isPremium ? runBackgroundTextPass(runningPhases: runningPhases) : ()
    // Runs OCR (if enabled) before the AI cache pass, so the text
    // layers exist when the cache entries are computed.
    let result = await runPhase(
        "processing",
        in: runningPhases,
        describe: { ["documentCount": "\(documents.count)", "ocrCount": "\($0.ocrCount)", "aiCacheCount": "\($0.aiCacheCount)"] },
        operation: { await documentProcessor.processUntaggedDocuments(documents) }
    )
    await textPass

    // Whether `NSMetadataQuery` reports an in-place rewrite by its own process is
    // undocumented, so the rescan is explicit.
    if result.ocrCount > 0 {
        try await runPhase("rescan", in: runningPhases) {
            try await archiveStore.reloadDocuments()
            await waitForInitialDocumentLoad()
        }
    }
    return result
}

/// The run's share of the text index, with the evictions that follow it.
private func runBackgroundTextPass(runningPhases: LockIsolated<Set<String>>) async {
    @Dependency(\.archiveIndexer) var archiveIndexer
    await runPhase("textPass", in: runningPhases, describe: { (indexed: [Document]) in ["processedCount": "\(indexed.count)"] }, operation: {
        let indexed = await archiveIndexer.indexPendingTexts(backgroundIndexBudget)
        await evictLocalCopies(of: indexed)
        return indexed
    })
}

/// Completes a background task exactly once, by the run itself or by the watchdog.
actor BackgroundTaskCompletion {
    private let completeTask: @Sendable (_ success: Bool) -> Void
    private var isCompleted = false

    init(_ completeTask: @escaping @Sendable (_ success: Bool) -> Void) {
        self.completeTask = completeTask
    }

    func complete(success: Bool, completion: String, metadata: Logger.Metadata = [:]) {
        guard !isCompleted else { return }
        isCompleted = true
        completeTask(success)
        var metadata = metadata
        metadata["success"] = "\(success)"
        metadata["completion"] = "\(completion)"
        Logger.backgroundTask.notice("Background task completed", metadata: metadata)
    }

    /// Called on expiration. The run stops at its next cancellation check, and `extractText` has
    /// none, so a document PDFKit is still parsing would keep the task open past its end.
    func completeAfterGracePeriod() async {
        @Dependency(\.continuousClock) var clock
        try? await clock.sleep(for: .seconds(5))
        complete(success: false, completion: "watchdog")
    }
}

/// Waits for the metadata reconcile, which the text pass is gated on.
///
/// The wait ends early when the task expires: the cancellation stops the sleep as well.
@discardableResult
private func waitForInitialDocumentLoad() async -> Bool {
    @Dependency(\.archiveIndexer) var archiveIndexer
    let reconciled = await archiveIndexer.waitWhileReconciling(initialLoadTimeout)
    if !reconciled {
        Logger.backgroundTask.warning("Timed out waiting for the initial document load")
    }
    return reconciled
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

    // TODO: Remove `evictedCount` and the `Evicted local copies` line with the diagnostic logs (#339).
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

// TODO: Remove with the diagnostic logs (#339): call the operations directly and drop `runningPhases`.
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
        @Dependency(\.premium) var premium
        return await premium.currentStatus() == .active
    }
}
