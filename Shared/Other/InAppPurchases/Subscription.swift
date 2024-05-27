//
//  Subscription.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 23.05.24.
//

/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The enumeration that defines the Backyard Birds Pass' status.
*/

import OSLog
import StoreKit
import SwiftUI

@Observable final class Subscription {
    fileprivate(set) var status: SubscriptionStatus = .loading
    var isSubscribed: Binding<Bool> {
        Binding(get: {
            self.status != .active
        }, set: { _ in
            Logger.inAppPurchase.errorAndAssert("Must not set isSubscribed state")
        })
    }
}

enum SubscriptionStatus: String {
    case loading, active, inactive
}

private struct IAPTaskModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(Subscription.self) var subscription

    func body(content: Content) -> some View {
        content
            .subscriptionStatusTask(for: Constants.inAppPurchaseGroupId) { state in
                Logger.inAppPurchase.info("Received a new subscriptionStatus")

                switch state {
                case .failure(let error):
                    Logger.inAppPurchase.error("Failed to check subscription status: \(error)")
                    subscription.status = .inactive
                case .success(let status):
                    let hasSubscription = !status
                        .filter { [.subscribed, .inBillingRetryPeriod, .inGracePeriod].contains($0.state) }
                        .isEmpty
                    Logger.inAppPurchase.info("Successfully received statusTask - hasSubscription: \(hasSubscription)")
                    subscription.status = hasSubscription ? .active : .inactive
                case .loading:
                    Logger.inAppPurchase.debug("Got loading status task")
                    subscription.status = .loading
                @unknown default:
                    Logger.inAppPurchase.errorAndAssert("Got unkown status in subscriptionStatusTask")
                    break
                }
            }
            .task {
                // look for lifetime purchase
                for await result in Transaction.currentEntitlements {
                    await process(transaction: result)
                }
            }
            .task {
                // observeTransactionUpdates
                for await update in StoreKit.Transaction.updates {
                    await process(transaction: update)
                }
                
            }
            .task {
                // checkForUnfinishedTransactions
                for await transaction in Transaction.unfinished {
                    let unsafeTransaction = transaction.unsafePayloadValue
                    Logger.inAppPurchase.log("""
                                Processing unfinished transaction ID \(unsafeTransaction.id) for \
                                \(unsafeTransaction.productID)
                                """)
                    Task.detached(priority: .background) {
                        await process(transaction: transaction)
                    }
                }
                
            }
    }
    
    private func process(transaction verificationResult: VerificationResult<StoreKit.Transaction>) async {
        do {
            let unsafeTransaction = verificationResult.unsafePayloadValue
            Logger.inAppPurchase.log("""
                Processing transaction ID \(unsafeTransaction.id) for \
                \(unsafeTransaction.productID)
                """)
        }
        
        let transaction: StoreKit.Transaction
        switch verificationResult {
        case .verified(let t):
            Logger.inAppPurchase.debug("""
                Transaction ID \(t.id) for \(t.productID) is verified
                """)
            transaction = t
        case .unverified(let t, let error):
            // Log failure and ignore unverified transactions
            Logger.inAppPurchase.error("""
                Transaction ID \(t.id) for \(t.productID) is unverified: \(error)
                """)
            return
        }
        
        if case .autoRenewable = transaction.productType {
            // We can just finish the transction since we will grant access to
            // the subscription based on the subscription status.
            await transaction.finish()
        } else if case .nonConsumable = transaction.productType {
            await transaction.finish()
            
            guard transaction.productID == "LIFETIME" else { return }
            if let revocationDate = transaction.revocationDate,
               revocationDate > Date() {
                subscription.status = .active
            } else {
                subscription.status = .active
            }
        } else {
            Logger.inAppPurchase.errorAndAssert("Found a non auto renewable product type \(transaction.productType)")
        }
    }
}

extension View {
    func inAppPurchasesSetup() -> some View {
        modifier(IAPTaskModifier())
    }
}
