//
//  BackgroundTaskManager.swift
//  ArchiverLib
//
//  Created by Claude on 31.10.25.
//

import BackgroundTasks
import ComposableArchitecture
import Foundation
import OSLog
import Shared

/// Manages background tasks for cache processing on iOS
@available(iOS 26, macOS 26, *)
public actor BackgroundTaskManager: Log {
    /// Background task identifier for cache processing
    public static let cacheProcessingTaskIdentifier = "com.pdf-archiver.cache-processing"

    @Dependency(\.contentExtractorStore) var contentExtractorStore
    @Dependency(\.archiveStore) var archiveStore
    @Dependency(\.textAnalyser) var textAnalyser

    private var customPrompt: String?

    public init() {}

    /// Register background task handlers
    /// Must be called early in app lifecycle (in app init)
    public static func registerTaskHandlers() {
        #if os(iOS)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: cacheProcessingTaskIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            Task {
                await BackgroundTaskManager().handleCacheProcessing(task: processingTask)
            }
        }
        Logger.backgroundTask.info("Background task handler registered")
        #endif
    }

    /// Schedule the cache processing background task
    /// - Parameter customPrompt: Optional custom prompt for extraction
    public static func scheduleCacheProcessing(customPrompt: String? = nil) {
        #if os(iOS)
        let request = BGProcessingTaskRequest(identifier: cacheProcessingTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = true // Only run when connected to power

        do {
            try BGTaskScheduler.shared.submit(request)
            Logger.backgroundTask.info("Cache processing task scheduled")
        } catch {
            Logger.backgroundTask.error("Failed to schedule cache processing task: \(error)")
        }
        #endif
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
            task.setTaskCompleted(success: true)
            Logger.backgroundTask.info("Background cache processing completed successfully")
        } catch {
            Logger.backgroundTask.error("Background cache processing failed: \(error)")
            task.setTaskCompleted(success: false)
        }

        // Reschedule for next time
        Self.scheduleCacheProcessing(customPrompt: customPrompt)
    }
}
