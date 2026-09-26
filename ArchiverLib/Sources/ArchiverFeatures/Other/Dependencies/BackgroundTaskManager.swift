//
//  BackgroundTaskManager.swift
//  ArchiverLib
//
//  Created by Claude on 31.10.25.
//

#if os(iOS)
import ArchiverDatabase
import ArchiverModels
import BackgroundTasks
import ComposableArchitecture
import Foundation
import Logging
import Shared
import SQLiteData
import UserNotifications

extension BGProcessingTask: @unchecked @retroactive Sendable {}
extension BGTaskScheduler: @unchecked @retroactive Sendable {}

/// Manages background tasks for cache processing on iOS
public actor BackgroundTaskManager: Log {
    /// Background task identifier for cache processing
    public static let cacheProcessingTaskIdentifier = "de.JulianKahnert.PDFArchiveViewer.pdf-processing"

    private static let scheduler = BGTaskScheduler.shared

    /// Documents per run, matched to `SearchIndexDownloads.batchSize` so extraction does not fall
    /// behind the downloads. An expiring task cancels the run and leaves the rest pending.
    private static let indexBudget = 250

    /// How long a cold start may take before the run gives up on the metadata. The iCloud metadata
    /// gather of a 3.000-document archive needs about half a minute, a first download far longer.
    private static let initialLoadTimeout = Duration.seconds(5 * 60)

    @Dependency(\.archiveIndexer) var archiveIndexer
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.documentProcessor) var documentProcessor
    @Dependency(\.archiveStore) var archiveStore
    @SharedReader(.backgroundCacheNotificationsEnabled) var shouldNotify: Bool

    private init() {}

    /// Register background task handlers
    /// Must be called early in app lifecycle (in app init)
    public static func registerTaskHandlers() {
        scheduler.register(
            forTaskWithIdentifier: cacheProcessingTaskIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                Logger.backgroundTask.error("Did not receive a BGProcessingTask")
                return
            }
            let manager = BackgroundTaskManager()
            Task {
                await manager.handleCacheProcessing(task: processingTask)
            }
        }
        Logger.backgroundTask.info("Background task handler registered")
    }

    /// Schedule the cache processing background task
    public static func scheduleCacheProcessing() {
        @Shared(.downloadAllForSearch) var downloadAllForSearch: Bool

        let request = BGProcessingTaskRequest(identifier: cacheProcessingTaskIdentifier)
        // Only the opt-in download needs the network; extraction reads local files.
        request.requiresNetworkConnectivity = downloadAllForSearch
        request.requiresExternalPower = true
        let metadata: Logger.Metadata = [
            "requiresNetwork": "\(request.requiresNetworkConnectivity)",
            "requiresPower": "\(request.requiresExternalPower)"
        ]
        do {
            try scheduler.submit(request)
            Logger.backgroundTask.notice("Cache processing task scheduled", metadata: metadata)
        } catch {
            Logger.backgroundTask.error("Failed to schedule cache processing task", metadata: metadata.merging([
                "error": "\(LogRedact.describe(error))"
            ]) { _, error in error })
        }
    }

    public static func cancelCacheProcessing() {
        scheduler.cancel(taskRequestWithIdentifier: cacheProcessingTaskIdentifier)
    }

    /// Handle cache processing background task
    private func handleCacheProcessing(task: BGProcessingTask) async {
        Logger.backgroundTask.info("Background cache processing started")
        // A background launch never shows the UI, whose start is where this is logged otherwise.
        await AppStateLog.log()
        let startTime = Date()
        // A lock, not actor state: the expiration handler is a synchronous callback on any thread.
        let runningPhases = LockIsolated<Set<String>>([])

        // Use a cancellable task so the expiration handler can stop work
        let processingTask = Task {
            // A cold background launch has no scene, so nothing else starts the folder scan, and
            // the wait below gives that scan the writer connection before the text pass takes it.
            try await runPhase("reload", in: runningPhases) {
                try await archiveStore.reloadDocuments()
            }
            await runPhase("initialLoadWait", in: runningPhases, describe: { ["reconciled": "\($0)"] }, operation: {
                await waitForInitialDocumentLoad()
            })

            let documents = try await database.read { db in
                try Document.inbox.fetchAll(db) + Document.aiContext().fetchAll(db)
            }
            // Runs OCR (if enabled) before the AI cache pass, so the text
            // layers exist when the cache entries are computed.
            let result = await runPhase(
                "processing",
                in: runningPhases,
                describe: { ["documentCount": "\(documents.count)", "ocrCount": "\($0.ocrCount)", "aiCacheCount": "\($0.aiCacheCount)"] },
                operation: { await documentProcessor.processUntaggedDocuments(documents) }
            )

            // Whether `NSMetadataQuery` reports an in-place rewrite by its own process is
            // undocumented, so the rescan is explicit - and it precedes the text pass.
            if result.ocrCount > 0 {
                try await runPhase("rescan", in: runningPhases) {
                    try await archiveStore.reloadDocuments()
                    await waitForInitialDocumentLoad()
                }
            }

            let isPremium = await runPhase("premium", in: runningPhases, describe: { ["premium": "\($0)"] }, operation: {
                await PremiumEntitlement.isActive()
            })
            if isPremium {
                await runPhase("prefetch", in: runningPhases) {
                    await SearchIndexDownloads.requestNextBatch()
                }
                await runPhase("textPass", in: runningPhases, describe: { (indexed: [Document]) in ["processedCount": "\(indexed.count)"] }, operation: {
                    let indexed = await archiveIndexer.indexPendingTexts(Self.indexBudget)
                    await evictLocalCopies(of: indexed)
                    return indexed
                })
            }
            return result
        }

        // Set expiration handler to cancel the work instead of completing the task directly
        task.expirationHandler = {
            Logger.backgroundTask.warning("Background cache processing expired", metadata: [
                "elapsedSeconds": "\(Int(Date().timeIntervalSince(startTime)))",
                "phase": "\(runningPhases.value.sorted().joined(separator: "+"))"
            ])
            processingTask.cancel()

            // Extraction observes cancellation per page, so the task returns within a page's
            // parse time; this guards against a pathological one.
            Task {
                try? await Task.sleep(for: .seconds(5))
                guard !processingTask.isCancelled else { return }
                task.setTaskCompleted(success: false)
                Logger.backgroundTask.notice("Background task completed", metadata: ["success": "false", "completion": "watchdog"])
            }
        }

        do {
            let result = try await processingTask.value
            let processingDuration = Date().timeIntervalSince(startTime)

            if shouldNotify {
                // Show local notification on success
                let duration = Duration.seconds(processingDuration)
                let durationText = duration.formatted(.units(width: .wide))
                let body = "Added a text layer to \(result.ocrCount) document\(result.ocrCount == 1 ? "" : "s") and created \(result.aiCacheCount) new cache\(result.aiCacheCount == 1 ? "" : "s") in \(durationText)."
                await UNUserNotificationCenter.current().showLocalNotification(
                    title: "Processing Completed",
                    body: body
                )
            }

            task.setTaskCompleted(success: true)
            Logger.backgroundTask.notice("Background task completed", metadata: [
                "success": "true",
                "completion": "normal",
                "ocrCount": "\(result.ocrCount)",
                "aiCacheCount": "\(result.aiCacheCount)",
                "durationSeconds": "\(processingDuration)"
            ])
        } catch {
            Logger.backgroundTask.error("Background cache processing failed", metadata: [
                "error": "\(LogRedact.describe(error))",
                "phase": "\(runningPhases.value.sorted().joined(separator: "+"))"
            ])

            if shouldNotify, !processingTask.isCancelled {
                await UNUserNotificationCenter.current().showLocalNotification(
                    title: "Processing Failed",
                    body: "Apple Intelligence cache processing failed: \(error.localizedDescription)"
                )
            }

            task.setTaskCompleted(success: false)
            Logger.backgroundTask.notice("Background task completed", metadata: [
                "success": "false",
                "completion": "normal",
                "durationSeconds": "\(Date().timeIntervalSince(startTime))"
            ])
        }

        // Reschedule for next time
        Self.scheduleCacheProcessing()
    }

    /// Waits for the metadata reconcile, which the text pass is gated on.
    ///
    /// The wait ends early when the task expires: the cancellation stops the sleep as well.
    @discardableResult
    private func waitForInitialDocumentLoad() async -> Bool {
        let reconciled = await archiveIndexer.waitWhileReconciling(Self.initialLoadTimeout)
        if !reconciled {
            Logger.backgroundTask.warning("Timed out waiting for the initial document load")
        }
        return reconciled
    }
}
#endif
