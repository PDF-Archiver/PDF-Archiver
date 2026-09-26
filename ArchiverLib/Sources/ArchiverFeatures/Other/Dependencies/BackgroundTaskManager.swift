//
//  BackgroundTaskManager.swift
//  ArchiverLib
//
//  Created by Claude on 31.10.25.
//

#if os(iOS)
import ArchiverModels
import BackgroundTasks
import ComposableArchitecture
import Foundation
import Logging
import Shared
import UserNotifications

extension BGProcessingTask: @unchecked @retroactive Sendable {}
extension BGTaskScheduler: @unchecked @retroactive Sendable {}

/// Manages background tasks for cache processing on iOS
public actor BackgroundTaskManager: Log {
    /// Background task identifier for cache processing
    public static let cacheProcessingTaskIdentifier = "de.JulianKahnert.PDFArchiveViewer.pdf-processing"

    private static let scheduler = BGTaskScheduler.shared

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
        // TODO: Remove with the diagnostic logs (#339).
        // A background launch never shows the UI, whose start is where this is logged otherwise.
        await AppStateLog.log()
        let startTime = Date()
        // TODO: Remove `runningPhases` and its `phase` log fields with the diagnostic logs (#339).
        // A lock, not actor state: the expiration handler is a synchronous callback on any thread.
        let runningPhases = LockIsolated<Set<String>>([])
        // Rescheduled together with the completion, so a watchdog completion schedules the next run.
        let completion = BackgroundTaskCompletion { success in
            task.setTaskCompleted(success: success)
            Self.scheduleCacheProcessing()
        }

        // Use a cancellable task so the expiration handler can stop work
        let processingTask = Task {
            try await runBackgroundProcessing(runningPhases: runningPhases)
        }

        // Set expiration handler to cancel the work instead of completing the task directly
        task.expirationHandler = {
            Logger.backgroundTask.warning("Background cache processing expired", metadata: [
                "elapsedSeconds": "\(Int(Date().timeIntervalSince(startTime)))",
                "phase": "\(runningPhases.value.sorted().joined(separator: "+"))"
            ])
            processingTask.cancel()
            Task {
                await completion.completeAfterGracePeriod()
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

            await completion.complete(success: true, completion: "normal", metadata: [
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

            await completion.complete(success: false, completion: "normal", metadata: [
                "durationSeconds": "\(Date().timeIntervalSince(startTime))"
            ])
        }
    }
}
#endif
