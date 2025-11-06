//
//  BackgroundTaskManager.swift
//  ArchiverLib
//
//  Created by Claude on 31.10.25.
//

#if os(iOS)
import BackgroundTasks
import ComposableArchitecture
import Foundation
import OSLog
import Shared
import UserNotifications

extension BGProcessingTask: @unchecked @retroactive Sendable {}
extension BGTaskScheduler: @unchecked @retroactive Sendable {}

/// Manages background tasks for cache processing on iOS
@available(iOS 26, *)
public actor BackgroundTaskManager: Log {
    /// Background task identifier for cache processing
    public static let cacheProcessingTaskIdentifier = "de.JulianKahnert.PDFArchiveViewer.pdf-processing"

    // TODO: change this debug flag
    private static let shouldNotify = true
    private static let scheduler = BGTaskScheduler.shared

    @Dependency(\.contentExtractorStore) var contentExtractorStore
    @Dependency(\.archiveStore) var archiveStore
    @Dependency(\.textAnalyser) var textAnalyser
    @SharedReader(.appleIntelligenceCustomPrompt) var customPrompt: String?

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

        // Set expiration handler
        task.expirationHandler = {
            Logger.backgroundTask.warning("Background cache processing expired")
            task.setTaskCompleted(success: false)
        }

        do {
            let documents = try await archiveStore.getDocuments()
            await contentExtractorStore.processUntaggedDocumentsInBackground(
                documents,
                textAnalyser.getTextFrom,
                customPrompt
            )

            if Self.shouldNotify {
                // Show local notification on success
                await UNUserNotificationCenter.current().showLocalNotification(
                    title: "Processing Completed",
                    body: "Apple Intelligence cache processing completed successfully."
                )
            }

            task.setTaskCompleted(success: true)
            Logger.backgroundTask.info("Background cache processing completed successfully")
        } catch {
            Logger.backgroundTask.error("Background cache processing failed: \(error)")

            if Self.shouldNotify {
                // Show local notification on failure
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
}
#endif
