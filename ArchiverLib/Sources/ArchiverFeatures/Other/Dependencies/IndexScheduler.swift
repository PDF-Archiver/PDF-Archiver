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
            #if os(iOS)
            BackgroundTaskManager.scheduleCacheProcessing()
            #else
            await MacBackgroundActivity.shared.start()
            #endif
        },
        cancel: {
            #if os(iOS)
            BackgroundTaskManager.cancelCacheProcessing()
            #else
            await MacBackgroundActivity.shared.stop()
            #endif
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
