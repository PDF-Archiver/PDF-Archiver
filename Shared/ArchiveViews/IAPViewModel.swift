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

final class IAPViewModel: ObservableObject, Log {

    @Published var level1Name = "Level 1"
    @Published var level2Name = "Level 2"
    @Published var lifetimeLicenseName: String?

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
            log.info("IAPView - buy: Monthly subscription.")
            do {
                try iapService.buy(subscription: .monthly)
                presentationMode.wrappedValue.dismiss()
            } catch {
                NotificationCenter.default.postAlert(error)
            }
        case .level2:
            log.info("IAPView - buy: Yearly subscription.")
            do {
                try iapService.buy(subscription: .yearly)
                presentationMode.wrappedValue.dismiss()
            } catch {
                NotificationCenter.default.postAlert(error)
            }
        case .lifetime:
            log.info("IAPView - buy: lifetime license.")
            do {
                try iapService.buy(subscription: .lifetime)
                presentationMode.wrappedValue.dismiss()
            } catch {
                NotificationCenter.default.postAlert(error)
            }
        case .restore:
            log.info("IAPView - Restore purchases.")
            iapService.restorePurchases()
            presentationMode.wrappedValue.dismiss()
        case .cancel:
            log.info("IAPView - Cancel subscription view.")
            presentationMode.wrappedValue.dismiss()
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
            case "LIFETIME":
                guard let localizedPrice = product.localizedPrice else { continue }
                lifetimeLicenseName = localizedPrice
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
        case lifetime
        case restore
        case cancel
    }
}
