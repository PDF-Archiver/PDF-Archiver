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
import OSLog
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

            while !Task.isCancelled {
                let pendingCount = await archiveIndexer.pendingTextCount()
                guard pendingCount > 0 else {
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
                guard await PremiumEntitlement.isActive() else {
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
                await archiveIndexer.indexPendingTexts(10)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    )
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
