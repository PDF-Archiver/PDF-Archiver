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
import OSLog
import Shared
import SQLiteData
import UserNotifications

extension BGProcessingTask: @unchecked @retroactive Sendable {}
extension BGTaskScheduler: @unchecked @retroactive Sendable {}

/// Manages background tasks for cache processing on iOS
@available(iOS 26, *)
public actor BackgroundTaskManager: Log {
    /// Background task identifier for cache processing
    public static let cacheProcessingTaskIdentifier = "de.JulianKahnert.PDFArchiveViewer.pdf-processing"

    private static let scheduler = BGTaskScheduler.shared

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
        let request = BGProcessingTaskRequest(identifier: cacheProcessingTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = true // Only run when connected to power
        do {
            try scheduler.submit(request)
            Logger.backgroundTask.info("Cache processing task scheduled")
        } catch {
            Logger.backgroundTask.error("Failed to schedule cache processing task: \(error)")
        }
    }

    /// Handle cache processing background task
    private func handleCacheProcessing(task: BGProcessingTask) async {
        Logger.backgroundTask.info("Background cache processing started")
        let startTime = Date()

        // Use a cancellable task so the expiration handler can stop work
        let processingTask = Task {
            // A cold background launch has no scene, so nothing else starts the folder scan;
            // `reloadDocuments` raises `isReconciling` before it returns.
            try await archiveStore.reloadDocuments()
            await waitForInitialDocumentLoad()

            let documents = try await database.read { db in
                try Document.inbox.fetchAll(db) + Document.aiContext().fetchAll(db)
            }
            // Runs OCR (if enabled) before the AI cache pass, so the text
            // layers exist when the cache entries are computed.
            return await documentProcessor.processUntaggedDocuments(documents)
        }

        // Set expiration handler to cancel the work instead of completing the task directly
        task.expirationHandler = {
            Logger.backgroundTask.warning("Background cache processing expired")
            processingTask.cancel()
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
            Logger.backgroundTask.info("Background processing completed: \(result.ocrCount) OCR, \(result.aiCacheCount) caches in \(processingDuration)s")
        } catch {
            Logger.backgroundTask.error("Background cache processing failed: \(error)")

            if shouldNotify, !processingTask.isCancelled {
                await UNUserNotificationCenter.current().showLocalNotification(
                    title: "Processing Failed",
                    body: "Apple Intelligence cache processing failed: \(error.localizedDescription)"
                )
            }

            task.setTaskCompleted(success: false)
        }

        // Reschedule for next time
        Self.scheduleCacheProcessing()
    }

    /// Wait until the initial reconcile has finished, but no longer than a fixed
    /// timeout - the background execution window is limited.
    private func waitForInitialDocumentLoad() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [database] in
                @FetchOne(IndexerState.find(IndexerState.singletonID).select(\.isReconciling), database: database)
                var isReconciling = true
                for await value in $isReconciling.publisher.values where !value {
                    return
                }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                Logger.backgroundTask.warning("Timed out waiting for the initial document load")
            }
            await group.next()
            group.cancelAll()
        }
    }
}
#endif
