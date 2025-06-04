//
//  IAP.swift
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

struct IAP: ViewModifier {
    enum Status: String {
        case loading, active, inactive
    }

    @Environment(NavigationModel.self) var navigationModel

    @State private var subscriptionStatus: Status = .loading
    @State private var lifetimePurchaseStatus: Status = .loading

    func body(content: Content) -> some View {
        content
            .onChange(of: subscriptionStatus.rawValue) { oldValue, newValue in
                Logger.inAppPurchase.debug("subscriptionStatus changed: \(oldValue) -> \(newValue)")
                updatePremiumStatus()
            }
            .onChange(of: lifetimePurchaseStatus.rawValue) { oldValue, newValue in
                Logger.inAppPurchase.debug("lifetimePurchaseStatus changed: \(oldValue) -> \(newValue)")
                updatePremiumStatus()
            }
            .subscriptionStatusTask(for: Constants.inAppPurchaseGroupId, priority: .background) { (state: EntitlementTaskState<[Product.SubscriptionInfo.Status]>) in
                Logger.inAppPurchase.info("Received a new subscriptionStatus")

                switch state {
                case .failure(let error):
                    Logger.inAppPurchase.error("Failed to check subscription status: \(error)")
                    subscriptionStatus = .inactive
                case .success(let status):
                    let hasSubscription = !status
                        .filter { [.subscribed, .inBillingRetryPeriod, .inGracePeriod].contains($0.state) }
                        .isEmpty
                    Logger.inAppPurchase.info("Successfully received statusTask - hasSubscription: \(hasSubscription)")
                    subscriptionStatus = hasSubscription ? .active : .inactive
                case .loading:
                    Logger.inAppPurchase.debug("Got loading status task")
                @unknown default:
                    Logger.inAppPurchase.errorAndAssert("Got unkown status in subscriptionStatusTask")
                }
            }
            .task {
                guard subscriptionStatus == .loading else { return }

                // if no subscription was found after 2 seconds, we assume there is no active subscription
                try? await Task.sleep(for: .seconds(3))
                guard subscriptionStatus == .loading else { return }
                lifetimePurchaseStatus = .inactive
            }
            .task {
                guard subscriptionStatus == .loading else { return }

                // if no lifetime purchase was found after 2 seconds, we assume there is no active subscription
                try? await Task.sleep(for: .seconds(3))
                guard lifetimePurchaseStatus == .loading else { return }
                lifetimePurchaseStatus = .inactive
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
                    await process(transaction: transaction)
                }
            }
    }

    private func updatePremiumStatus() {
        // if either the subscription or lifetime purchase is loading, we still want to stay in the loading state
        guard subscriptionStatus != .loading && lifetimePurchaseStatus != .loading else {
            navigationModel.premiumStatus = .loading
            return
        }

        // validate subscription
        let hasPremium = subscriptionStatus == .active || lifetimePurchaseStatus == .active
        navigationModel.premiumStatus = hasPremium ? .active : .inactive
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
                lifetimePurchaseStatus = .inactive
            } else {
                lifetimePurchaseStatus = .active
            }
        } else {
            Logger.inAppPurchase.errorAndAssert("Found a non auto renewable product type \(transaction.productType)")
        }
    }
}

extension View {
    func inAppPurchasesSetup() -> some View {
        modifier(IAP())
    }
}
