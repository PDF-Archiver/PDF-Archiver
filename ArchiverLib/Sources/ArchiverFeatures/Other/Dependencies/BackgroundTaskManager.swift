//
//  BackgroundTaskManager.swift
//  ArchiverLib
//
//  Created by Claude on 31.10.25.
//

#if os(iOS)
import BackgroundTasks
import ComposableArchitecture
import DocumentProcessingPipeline
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

    private static let scheduler = BGTaskScheduler.shared

    @Dependency(\.archiveStore) var archiveStore
    @Dependency(\.documentProcessingPipeline) var documentProcessingPipeline
    @SharedReader(.ocrEnabled) var ocrEnabled: Bool
    @SharedReader(.appleIntelligenceEnabled) var aiEnabled: Bool
    @SharedReader(.appleIntelligenceCacheEnabled) var aiCacheEnabled: Bool
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

        // Set expiration handler
        task.expirationHandler = {
            Logger.backgroundTask.warning("Background cache processing expired")
            task.setTaskCompleted(success: false)
        }

        do {
            let documents = try await archiveStore.getDocuments()
            var steps: Set<PipelineConfiguration.StepKind> = []
            if ocrEnabled {
                steps.insert(.ocr)
            }
            if aiEnabled && aiCacheEnabled {
                steps.insert(.aiCache)
            }

            let untaggedURLs = documents.filter { !$0.isTagged }.map(\.url)
            let config = PipelineConfiguration(
                urls: untaggedURLs,
                steps: steps
            )
            let result = await documentProcessingPipeline.processAndWait(config)

            let processingDuration = Date().timeIntervalSince(startTime)

            if shouldNotify {
                let duration = Duration.seconds(processingDuration)
                let durationText = duration.formatted(.units(width: .wide))
                let summary = result.stepResults
                    .filter { $0.processedCount > 0 }
                    .map { "\($0.step.rawValue): \($0.processedCount)" }
                    .joined(separator: ", ")
                let body = summary.isEmpty
                    ? "No documents to process (\(durationText))."
                    : "\(summary) in \(durationText)."
                await UNUserNotificationCenter.current().showLocalNotification(
                    title: "Processing Completed",
                    body: body
                )
            }

            task.setTaskCompleted(success: true)
            let totalProcessed = result.stepResults.reduce(0) { $0 + $1.processedCount }
            Logger.backgroundTask.info("Background processing completed: \(totalProcessed) documents in \(processingDuration)s")
        } catch {
            Logger.backgroundTask.error("Background cache processing failed: \(error)")

            if shouldNotify {
                // Show local notification on failure
                await UNUserNotificationCenter.current().showLocalNotification(
                    title: "Processing Failed",
                    body: "Background processing failed: \(error.localizedDescription)"
                )
            }

            task.setTaskCompleted(success: false)
        }

        // Reschedule for next time
        Self.scheduleCacheProcessing()
    }
}
#endif
