//
//  IAPView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 23.05.24.
//

import SwiftUI

struct IAPView: View {
    let onCancel: () -> Void
    /// Called after a purchase made through this view is verified and finished, so the caller can
    /// re-evaluate `premiumStatus` - a same-device purchase completes through `Product.PurchaseResult`,
    /// not `Transaction.updates`, so nothing else observes it.
    let onPurchaseCompleted: () -> Void

    var body: some View {
        PaywallView(onCancel: onCancel, onPurchaseCompleted: onPurchaseCompleted)
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
