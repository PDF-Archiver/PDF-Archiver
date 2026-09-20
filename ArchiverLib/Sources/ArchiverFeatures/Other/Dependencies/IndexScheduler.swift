//
//  IndexScheduler.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverDatabase
import ComposableArchitecture
import Foundation
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

            while !Task.isCancelled {
                guard await archiveIndexer.pendingTextCount() > 0 else {
                    try? await Task.sleep(for: .seconds(60))
                    continue
                }
                guard await PremiumEntitlement.isActive() else {
                    // Long, but not forever: a purchase later in the session starts the index
                    // without asking the user to relaunch.
                    try? await Task.sleep(for: .seconds(300))
                    continue
                }

                // Ten at a time with a pause between batches: the writer connection is shared with
                // the reconcile, and a foreground pass must never be what the archive list waits on.
                await archiveIndexer.indexPendingTexts(10)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    )
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
