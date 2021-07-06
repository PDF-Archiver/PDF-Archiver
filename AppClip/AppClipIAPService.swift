//
//  AppClipIAPService.swift
//  AppClip
//
//  Created by Julian Kahnert on 23.10.20.
//

import ArchiveBackend
import Combine
import InAppPurchases
import StoreKit

final class AppClipIAPService: IAPServiceAPI {

    var productsPublisher: AnyPublisher<Set<SKProduct>, Never> {
        Just([]).eraseToAnyPublisher()
    }

    var appUsagePermitted = true

    var appUsagePermittedPublisher: AnyPublisher<Bool, Never> {
        Just(appUsagePermitted).eraseToAnyPublisher()
    }

    func buy(subscription: IAPService.SubscriptionType) throws { }

    func restorePurchases() { }
}
