//
//  IAPServiceAPI.swift
//  
//
//  Created by Julian Kahnert on 28.10.20.
//

import Combine
import StoreKit

public protocol IAPServiceAPI: class {

    var productsPublisher: AnyPublisher<Set<SKProduct>, Never> { get }
    var appUsagePermitted: Bool { get }
    var appUsagePermittedPublisher: AnyPublisher<Bool, Never> { get }

    func buy(subscription: IAPService.SubscriptionType) throws
    func restorePurchases()
}
