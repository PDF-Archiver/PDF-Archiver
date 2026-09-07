//
//  PremiumDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverModels
import ComposableArchitecture
import OSLog
import StoreKit

@DependencyClient
struct PremiumDependency: Sendable {
    /// One pass over `Transaction.currentEntitlements`; never returns `.loading`.
    var currentStatus: @Sendable () async -> PremiumStatus = { .inactive }
    /// Yields once per `Transaction.updates` delivery, after the verified transaction was finished.
    /// The receiver re-evaluates `currentStatus`; the stream carries no status of its own.
    var transactionUpdates: @Sendable () -> AsyncStream<Void> = { AsyncStream { $0.finish() } }
}

extension PremiumDependency: TestDependencyKey {
    static let previewValue = Self(
        currentStatus: { .active },
        transactionUpdates: { AsyncStream { _ in } }
    )

    static let testValue = Self()
}

extension PremiumDependency: DependencyKey {
    static let liveValue = PremiumDependency(
        currentStatus: {
            for await result in Transaction.currentEntitlements {
                switch result {
                case .unverified(let transaction, let error):
                    Logger.inAppPurchase.error("""
                        Transaction ID \(transaction.id) for \(transaction.productID) is unverified: \(error)
                        """)
                    continue

                case .verified(let transaction):
                    guard PremiumProduct.grantsPremium(productType: transaction.productType,
                                                       productID: transaction.productID,
                                                       subscriptionGroupID: transaction.subscriptionGroupID,
                                                       revocationDate: transaction.revocationDate) else { continue }
                    Logger.inAppPurchase.debug("currentStatus: .active")
                    return .active
                }
            }
            Logger.inAppPurchase.debug("currentStatus: .inactive")
            return .inactive
        },
        transactionUpdates: {
            let (stream, continuation) = AsyncStream<Void>.makeStream()
            let task = Task {
                for await result in Transaction.updates {
                    switch result {
                    case .verified(let transaction):
                        // Every renewal and every same-device purchase arrives here and must be
                        // finished, or StoreKit keeps redelivering it.
                        await transaction.finish()

                    case .unverified(let transaction, let error):
                        Logger.inAppPurchase.error("""
                            Transaction ID \(transaction.id) for \(transaction.productID) is unverified: \(error)
                            """)
                    }
                    continuation.yield()
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
            return stream
        }
    )
}

extension DependencyValues {
    var premium: PremiumDependency {
        get { self[PremiumDependency.self] }
        set { self[PremiumDependency.self] = newValue }
    }
}
