//
//  IAPHelper.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 22.06.18.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//  The structure is base on: https://www.raywenderlich.com/122144/in-app-purchase-tutorial
//

import os.log
import Purchases
import StoreKit

public enum Environment {
    case develop
    case testflight
    case release
}

public protocol IAPHelperDelegate: AnyObject {
    func found(products: Set<SKProduct>)
    func found(requestsRunning: Int)
    func changed(expirationDate: Date)
}

// setup default implementations for this delegate
public extension IAPHelperDelegate {
    func found(products: Set<SKProduct>) {}
    func found(requestsRunning: Int) {}
}

extension UserDefaults {

    private enum Names: String {
        case subscriptionExpiryDate = "SubscriptionExpiryDate"
    }

    var subscriptionExpiryDate: Date? {
        get {
            return UserDefaults.standard.object(forKey: Names.subscriptionExpiryDate.rawValue) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Names.subscriptionExpiryDate.rawValue)
        }
    }
}

public class IAPHelper {

    private static let subscriptionEntitlement = "subscription"

    private static var log = OSLog(subsystem: "ArchiveLib", category: "Self")

    public weak var delegate: IAPHelperDelegate?

    public private(set) var products = Set<SKProduct>() {
        didSet { delegate?.found(products: self.products) }
    }
    public private(set) var requestsRunning: Int = 0 {
        didSet { delegate?.found(requestsRunning: requestsRunning) }
    }

    private let productIdentifiers: Set<String>
    private let environment: Environment
    private let preSubscriptionPrefixes: [String]

    /// IAPHelper is a lightweight wrapper of `SwiftyStoreKit` that helps to verify in app purchases of e.g. `PDF Archiver`.
    /// - Parameters:
    ///   - productIdentifiers: App Store Connect purchase identifiers, e.g. `SUBSCRIPTION_MONTHLY`.
    ///   - environment: Current environment the app is running, e.g. `release`.
    ///   - apiKey: RevenueCat api key
    ///   - preSubscriptionPrefixes: Version prefixes that should be used to verify if a purchase was made before the subscription business model, e.g. `1.0` or `1.1.`.
    public init(productIdentifiers: Set<String>, environment: Environment, apiKey: String, preSubscriptionPrefixes: [String] = []) {
        self.productIdentifiers = productIdentifiers
        self.environment = environment
        self.preSubscriptionPrefixes = preSubscriptionPrefixes

        os_log("Subscription Expiration Date: %@", log: Self.log, type: .info, UserDefaults.standard.subscriptionExpiryDate?.description ?? "")

        // start revenue cat
        //Purchases.debugLogsEnabled = true
        Purchases.configure(withAPIKey: apiKey)

        Purchases.shared.products(Array(productIdentifiers)) { products in
            self.products = Set(products)
        }
//        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(2)) {
//            Purchases.shared.purchaserInfo { purchaserInfo, _ in
//
//                // setup migration
//                var isSubscribedInOldSystem = false
//                if let subscriptionExpiryDate = UserDefaults.standard.subscriptionExpiryDate,
//                    subscriptionExpiryDate > Date() {
//                    isSubscribedInOldSystem = true
//                }
//                let isSubscribedInRevenueCat = !(purchaserInfo?.entitlements.active.isEmpty ?? true)
//
//                // If the old system says we have a subscription, but RevenueCat does not
//                if isSubscribedInOldSystem && !isSubscribedInRevenueCat {
//                  // Tell Purchases to restoreTransactions.
//                  // This will sync the user's receipt with RevenueCat.
//                  Purchases.shared.restoreTransactions { (_, _) in }
//                }
//
//                _ = self.internalAppUsagePermitted(with: purchaserInfo)
//            }
//        }
    }

    public func appUsagePermitted() -> Bool {
        return true

        // skip app validation in this version
//        // debug/simulator/testflight: app usage is always permitted
//        guard environment == .release else {
//            return true
//        }
//
//        // no validation needed if the saved expiration date is not yet reached
//        if let expiryDate = UserDefaults.standard.subscriptionExpiryDate,
//            expiryDate > Date() {
//            return true
//        }
//
//        requestsRunning += 1
//        defer {
//            requestsRunning -= 1
//        }
//
//        var appUsagePermitted = false
//
//        let semaphore = DispatchSemaphore(value: 1)
//        Purchases.shared.purchaserInfo { (purchaserInfo, _) in
//            appUsagePermitted = self.internalAppUsagePermitted(with: purchaserInfo)
//            semaphore.signal()
//        }
//        let timeout = semaphore.wait(timeout: .now() + .seconds(5))
//        if timeout == .timedOut {
//            os_log("Failed to get permission!", log: Self.log, type: .error)
//            return false
//        }
//        return appUsagePermitted
    }

//    private func internalAppUsagePermitted(with purchaserInfo: Purchases.PurchaserInfo?) -> Bool {
//        guard let purchaserInfo = purchaserInfo else { return false }
//
//        // update the expiration date if it could be found
//        if let expirationDate = purchaserInfo.entitlements.all[IAPHelper.subscriptionEntitlement]?.expirationDate {
//            let oldExpirationDate = UserDefaults.standard.subscriptionExpiryDate
//            UserDefaults.standard.subscriptionExpiryDate = expirationDate
//            os_log("New Subscription Expiration Date: %@", log: Self.log, type: .info, expirationDate.description)
//
//            if oldExpirationDate != expirationDate {
//                self.delegate?.changed(expirationDate: expirationDate)
//            }
//        }
//
//        if let originalApplicationVersion = purchaserInfo.originalApplicationVersion,
//            self.preSubscriptionPrefixes.contains(where: { originalApplicationVersion.hasPrefix($0) }) {
//            // user bought the app before subscription model
//            return true
//        }
//
//        if purchaserInfo.entitlements.all[IAPHelper.subscriptionEntitlement]?.isActive == true {
//            // found a valid subscription
//            return true
//        }
//        return false
//    }

    public func buyProduct(_ productIdentifier: String, completion: ((_ successful: Bool) -> Void)? = nil) {

        requestsRunning += 1
        Purchases.shared.offerings { (offerings, _) in
            self.requestsRunning -= 1

            if let packages = offerings?.current?.availablePackages,
                let package = packages.first(where: { $0.product.productIdentifier == productIdentifier }) {

                self.requestsRunning += 1
                Purchases.shared.purchasePackage(package) { (_, _, _, _) in
                    self.requestsRunning -= 1

//                    let success = self.internalAppUsagePermitted(with: purchaseInfo)
//                    completion?(success)
                    completion?(true)
                }

            } else {
                completion?(true)
            }
        }
    }
//
//    public func restorePurchases() {
//        requestsRunning += 1
//        Purchases.shared.restoreTransactions { (purchaseInfo, _) in
//            _ = self.internalAppUsagePermitted(with: purchaseInfo)
//            self.requestsRunning -= 1
//        }
//    }
}
