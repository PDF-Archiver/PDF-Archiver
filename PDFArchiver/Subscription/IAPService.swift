//
//  IAPHelper.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 22.06.18.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//  The structure is base on: https://www.raywenderlich.com/122144/in-app-purchase-tutorial
//

//import ArchiveLib
import ArchiveLib
import Keys
import os.log
import StoreKit
import SwiftyStoreKit

public protocol IAPServiceDelegate: AnyObject {
    func found(products: Set<SKProduct>)
    func found(requestsRunning: Int)
}

// setup default implementations for this delegate
public extension IAPServiceDelegate {
    func found(products: Set<SKProduct>) {}
    func found(requestsRunning: Int) {}
}

public class IAPService: NSObject, Logging {

    private static let productIdentifiers = Set(["SUBSCRIPTION_MONTHLY_IOS", "SUBSCRIPTION_YEARLY_IOS_NEW"])
    private static let subscriptionExpiryDateKey = "SubscriptionExpiryDate"

    private var _expiryDate: Date?
    private var expiryDate: Date? {
        get {
            if _expiryDate == nil {
                _expiryDate = UserDefaults.standard.object(forKey: IAPService.subscriptionExpiryDateKey) as? Date
                os_log("Getting new expiry date: %@", log: IAPService.log, type: .debug, _expiryDate?.description ?? "NULL")
            }
            return _expiryDate
        }
        set {
            os_log("Setting new expiry date: %@", log: IAPService.log, type: .debug, newValue?.description ?? "NULL")
            _expiryDate = newValue
            UserDefaults.standard.set(newValue, forKey: IAPService.subscriptionExpiryDateKey)
        }
    }

    public weak var delegate: IAPServiceDelegate?

    public private(set) var products = Set<SKProduct>() {
        didSet { delegate?.found(products: self.products) }
    }
    public private(set) var requestsRunning: Int = 0 {
        didSet { delegate?.found(requestsRunning: requestsRunning) }
    }

    override public init() {

        super.init()

        // Start SwiftyStoreKit and complete transactions
        SwiftyStoreKit.completeTransactions(atomically: true) { purchases in
            for purchase in purchases {
                switch purchase.transaction.transactionState {
                case .purchased, .restored:
                    if purchase.needsFinishTransaction {
                        // Deliver content from server, then:
                        SwiftyStoreKit.finishTransaction(purchase.transaction)
                    }
                    // Unlock content

                default:
                    break // do nothing
                }
            }
        }

        // get products
        requestProducts()

        // release only: fetch receipt
        if Environment.get() == .production {
            _ = self.appUsagePermitted(appStart: true)
        }
    }

    // MARK: - StoreKit API

    public func appUsagePermitted(appStart: Bool = false) -> Bool {

        // debug/simulator/testflight: app usage is always permitted
        let environment = Environment.get()
        if environment == .develop || environment == .testflight {
            return true
        }

        if let expiryDate = self.expiryDate,
            expiryDate > Date() {
            return true

        } else {

            // could not found a valid exipryDate locally, so we have to fetch receipts and validate them
            // in a background thread
            DispatchQueue.global(qos: .userInitiated).async {
                // get local or remote receipt
                self.fetchReceipt(appStart: appStart)

                // validate receipt and check expiration date
                _ = self.saveNewExpiryDateOfReceipt()
            }
            return false
        }
    }

    public func buyProduct(_ product: SKProduct) {
        os_log("Buying %@ ...", log: IAPService.log, type: .info, product.productIdentifier)

        requestsRunning += 1
        SwiftyStoreKit.purchaseProduct(product, quantity: 1, atomically: true) { result in
            self.requestsRunning -= 1
            switch result {
            case .success(let purchase):
                os_log("Purchase successfull: %@", log: IAPService.log, type: .debug, purchase.productId)
                self.fetchReceipt()

                // validate receipt and save new expiry date
                _ = self.saveNewExpiryDateOfReceipt()

            case .error(let error):
                os_log("Purchase failed with error: %@", log: IAPService.log, type: .error, error.localizedDescription)
            }
        }
    }

    public func buyProduct(_ productIdentifier: String) {
        if let product = products.first(where: { $0.productIdentifier == productIdentifier }) {
            buyProduct(product)
        } else {
            os_log("Could not find any product for id: %@", log: IAPService.log, type: .error, productIdentifier)
        }
    }

    public func restorePurchases() {
        requestsRunning += 1
        SwiftyStoreKit.restorePurchases(atomically: true) { results in
            self.requestsRunning -= 1
            if !results.restoreFailedPurchases.isEmpty {
                os_log("Restore Failed: : %@", log: IAPService.log, type: .error, results.restoreFailedPurchases)
            } else if !results.restoredPurchases.isEmpty {
                os_log("Restore Success: %@", log: IAPService.log, type: .debug, results.restoredPurchases)
            } else {
                os_log("Nothing to Restore", log: IAPService.log, type: .info)
            }
        }
    }

    // MARK: - Helper Functions

    fileprivate func saveNewExpiryDateOfReceipt() {
        os_log("external start", log: IAPService.log, type: .info)

        // create apple validator
        let appleValidator = AppleReceiptValidator(service: .production, sharedSecret: PDFArchiverKeys().appstoreConnectSharedSecret)

        SwiftyStoreKit.verifyReceipt(using: appleValidator) { result in
            defer {
                os_log("Internal end", log: IAPService.log, type: .info)
            }
            os_log("Internal start", log: IAPService.log, type: .info)

            switch result {
            case .success(let receipt):

                for productId in IAPService.productIdentifiers {
                    // Verify the purchase of a Subscription
                    let purchaseResult = SwiftyStoreKit.verifySubscription(ofType: .autoRenewable, productId: productId, inReceipt: receipt)

                    switch purchaseResult {
                    case .purchased(let expiryDate, _):

                        os_log("%@ is valid until %@", log: IAPService.log, type: .debug, productId, expiryDate.description)

                        // set new expiration date
                        self.expiryDate = expiryDate

                        return

                    case .expired(let expiryDate, _):
                        os_log("%@ has expired since %@", log: IAPService.log, type: .debug, productId, expiryDate.description)
                    case .notPurchased:
                        os_log("The user has never purchased %@", log: IAPService.log, type: .debug, productId)
                    }
                }

            case .error(let error):
                print("Receipt verification failed: \(error)")
            }
        }
    }

    fileprivate func fetchReceipt(forceRefresh: Bool = false, appStart: Bool = false) {

        // refresh receipt if not reachable
        SwiftyStoreKit.fetchReceipt(forceRefresh: forceRefresh) { result in

            switch result {
            case .success:
                os_log("Fetching receipt was successful.", log: IAPService.log, type: .debug)
            case .error(let error):
                print("Fetch receipt failed: \(error)")
                if appStart {
                    os_log("Receipt not found, exit the app!", log: IAPService.log, type: .error)
                    exit(173)

                } else if !forceRefresh {
                    // we do not run in an infinite recurse situation since this will only be reached, if no forceRefresh was issued
                    os_log("Receipt not found, refreshing receipt.", log: IAPService.log, type: .info)
                    self.fetchReceipt(forceRefresh: true, appStart: false)
                }
            }
        }
    }

    private func requestProducts() {
        requestsRunning += 1
        SwiftyStoreKit.retrieveProductsInfo(IAPService.productIdentifiers) { result in
            self.requestsRunning -= 1
            self.products = result.retrievedProducts

            if !result.retrievedProducts.isEmpty {
                os_log("Found %@ products.", log: IAPService.log, type: .debug, String(result.retrievedProducts.count))
            } else if let invalidProductId = result.invalidProductIDs.first {
                os_log("Invalid product identifier:  %@", log: IAPService.log, type: .info, invalidProductId)
            } else {
                os_log("Retrieving product infos errored:  %@", log: IAPService.log, type: .info, result.error?.localizedDescription ?? "")
            }
        }
    }
}
