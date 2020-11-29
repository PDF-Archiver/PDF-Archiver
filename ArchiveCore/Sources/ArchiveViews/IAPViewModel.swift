//
//  IAPViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 13.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Combine
import InAppPurchases
import StoreKit
import SwiftUI

final class IAPViewModel: ObservableObject, Log {

    @Published var error: Error?
    @Published var level1Name = "Level 1"
    @Published var level2Name = "Level 2"

    private let iapService: IAPServiceAPI
    private var disposables = Set<AnyCancellable>()

    init(iapService: IAPServiceAPI) {
        self.iapService = iapService

        iapService.productsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] products in
                self?.updateButtonNames(with: products)
            }
            .store(in: &disposables)
    }

    func tapped(button: IAPButton, presentationMode: Binding<PresentationMode>) {

        switch button {
        case .level1:
            log.info("SubscriptionViewController - buy: Monthly subscription.")
            do {
                try iapService.buy(subscription: .monthly)
                presentationMode.dismiss()
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                }
            }
        case .level2:
            log.info("SubscriptionViewController - buy: Yearly subscription.")
            do {
                try iapService.buy(subscription: .yearly)
                presentationMode.dismiss()
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                }
            }
        case .restore:
            log.info("SubscriptionViewController - Restore purchases.")
            iapService.restorePurchases()
            presentationMode.dismiss()
        case .cancel:
            log.info("SubscriptionViewController - Cancel subscription view.")
            presentationMode.dismiss()
        }
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
                Self.log.error("Could not find product in IAP.", metadata: ["product_name": "\(product.localizedDescription)"])
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
