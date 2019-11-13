//
//  IAPViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 13.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Combine
import StoreKit
import SwiftUI

class IAPViewModel: ObservableObject {
    @Published var level1Name = "Level 1"
    @Published var level2Name = "Level 2"

    init() {
        // setup delegate
        IAP.service.delegate = self

        // setup button names
        guard !IAP.service.products.isEmpty else { return }
        updateButtonNames(with: IAP.service.products)
    }

    func tapped(button: IAPButton) {
        // TODO: implement this
        print("Tapped button \(button)")



//        @objc
//        private func subscribeLevel1() {
//            Log.send(.info, "SubscriptionViewController - buy: Monthly subscription.")
//            IAP.service.buyProduct("SUBSCRIPTION_MONTHLY_IOS")
//            cancel()
//        }
//
//        @objc
//        private func subscribeLevel2() {
//            Log.send(.info, "SubscriptionViewController - buy: Yearly subscription.")
//            IAP.service.buyProduct("SUBSCRIPTION_YEARLY_IOS_NEW")
//            cancel()
//        }
//
//        @objc
//        private func restore() {
//            Log.send(.info, "SubscriptionViewController - Restore purchases.")
//            IAP.service.restorePurchases()
//            let alert = UIAlertController(title: NSLocalizedString("subscription.restore.popup.title", comment: ""),
//                                          message: NSLocalizedString("subscription.restore.popup.message", comment: ""),
//                                          preferredStyle: .alert)
//            alert.addAction(UIAlertAction(title: "OK", style: .default) {_ in
//                self.cancel()
//            })
//            present(alert, animated: true, completion: nil)
//        }
//
//        @objc
//        private func cancel() {
//            Log.send(.info, "SubscriptionViewController - Cancel subscription view.")
//            if !IAP.service.appUsagePermitted() {
//                self.dismiss(animated: true, completion: completion)
//            } else {
//                self.dismiss(animated: true, completion: nil)
//            }
//        }


    }

    private func updateButtonNames(with products: Set<SKProduct>) {
        for product in products {
            switch product.productIdentifier {
            case "SUBSCRIPTION_MONTHLY_IOS":
                guard let localizedPrice = product.localizedPrice else { continue }
                level1Name = localizedPrice + " " + NSLocalizedString("per_month", comment: "")
            case "SUBSCRIPTION_YEARLY_IOS_NEW":
                guard let localizedPrice = product.localizedPrice else { continue }
                level2Name = localizedPrice + " " + NSLocalizedString("per_year", comment: "")
            default:
                Log.send(.error, "Could not find product in IAP.", extra: ["product_name": product.localizedDescription])
            }
        }
    }
}

extension IAPViewModel {
    enum IAPButton: String, CaseIterable {
        case level1
        case level2
        case restore
        case cancel
    }
}

extension IAPViewModel: IAPServiceDelegate {
    func unlocked() {
        tapped(button: .cancel)
    }

    func found(products: Set<SKProduct>) {
        updateButtonNames(with: products)
    }
}
