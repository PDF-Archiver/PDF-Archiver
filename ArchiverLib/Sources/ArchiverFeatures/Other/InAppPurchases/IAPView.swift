//
//  IAPView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 23.05.24.
//

import ArchiverModels
import Logging
import Shared
import StoreKit
import SwiftUI

struct IAPView: View {
    let onCancel: () -> Void
    /// Called after a purchase made through this view's store views is verified and
    /// finished, so the caller can re-evaluate `premiumStatus` - a same-device purchase completes
    /// through `Product.PurchaseResult`, not `Transaction.updates`, so nothing else observes it.
    let onPurchaseCompleted: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The lifetime offer lives in the marketing content so it scrolls above the
        // subscription picker instead of competing with a second, nested scroll view.
        SubscriptionStoreView(productIDs: PremiumProduct.subscriptions) {
            VStack(spacing: 30) {
                VStack(spacing: 10) {
                    Text("No Subscription", bundle: #bundle)
                        .font(.title)
                    Text("Could not find a subscription or lifetime purchase. Please choose one of the options below to support the app development.", bundle: #bundle)
                }

                features
                lifetime

                Text("Or as a subscription", bundle: #bundle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .subscriptionStoreControlStyle(.compactPicker)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.hidden, for: .cancellation)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    onCancel()
                } label: {
                    Text("Cancel", bundle: #bundle)
                }
            }
        }
        .frame(minWidth: 400, idealWidth: 500)
        .foregroundStyle(Color.paDarkGrayAsset)
        .containerBackground(Color.paBackgroundAsset, for: .subscriptionStore)
        .onInAppPurchaseCompletion { _, result in
            guard case .success(let purchaseResult) = result,
                  case .success(let verificationResult) = purchaseResult else { return }

            switch verificationResult {
            case .verified(let transaction):
                await transaction.finish()
                onPurchaseCompleted()

            case .unverified(let transaction, let error):
                Logger.inAppPurchase.error("Transaction is unverified", metadata: [
                    "transactionId": "\(transaction.id)",
                    "productId": "\(transaction.productID)",
                    "error": "\(LogRedact.describe(error))"
                ])
            }
        }
    }

    private var features: some View {
        VStack(alignment: .center, spacing: 16) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(String(localized: "Search PDFs", bundle: #bundle), systemImage: "magnifyingglass")
                    Label(String(localized: "iCloud Sync", bundle: #bundle), systemImage: "cloud")
                    Label(String(localized: "Open Source", bundle: #bundle), systemImage: "lock.open")
                }
                .frame(maxWidth: 220, alignment: .leading)
                .padding()
                .background(Color.paDarkGrayAsset.opacity(0.125))
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 6) {
                    Label(String(localized: "Scanner", bundle: #bundle), systemImage: "doc.text.viewfinder")
                    Label(String(localized: "Searchable PDFs", bundle: #bundle), systemImage: "doc.text.magnifyingglass")
                    Label(String(localized: "Tag PDFs", bundle: #bundle), systemImage: "tag")
                }
                .frame(maxWidth: 220, alignment: .leading)
                .padding()
                .background(Color.paDarkGrayAsset.opacity(0.125))
                .cornerRadius(8)
                .overlay(alignment: .topTrailing) {
                    Text("Premium", bundle: #bundle)
                        .padding(4)
                        .font(.footnote)
                        .foregroundColor(Color.paWhiteAsset)
                        .background(Color.paRedAsset)
                        .cornerRadius(8)
                        .transition(reduceMotion ? .opacity : .scale)
                        .offset(x: -16, y: -12)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .foregroundColor(Color.paRedAsset)
                Text("Support further development of a 1 person team.", bundle: #bundle)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 250)
            }
            .padding()
            .background(Color.paDarkGrayAsset.opacity(0.125))
            .cornerRadius(8)
        }
    }

    private var lifetime: some View {
        ProductView(id: PremiumProduct.lifetime)
            .productViewStyle(.large)
            .padding()
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.paRedAsset, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                Text("Recommended", bundle: #bundle)
                    .padding(4)
                    .font(.footnote)
                    .foregroundColor(Color.paWhiteAsset)
                    .background(Color.paRedAsset)
                    .cornerRadius(8)
                    .offset(x: -16, y: -12)
            }
    }
}

#if DEBUG
#Preview("IAP light", traits: .fixedLayout(width: 400, height: 500)) {
    IAPView(onCancel: { print("Cancel pressed") }, onPurchaseCompleted: {})
        .preferredColorScheme(.light)
}

#Preview("IAP dark", traits: .fixedLayout(width: 400, height: 500)) {
    IAPView(onCancel: { print("Cancel pressed") }, onPurchaseCompleted: {})
        .preferredColorScheme(.dark)
}
#endif
