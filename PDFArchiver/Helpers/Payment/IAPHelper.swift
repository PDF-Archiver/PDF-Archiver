//
//  IAPHelper.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 22.06.18.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//  The structure is base on: https://www.raywenderlich.com/122144/in-app-purchase-tutorial
//

import os.log
import StoreKit

protocol IAPHelperDelegate: AnyObject {
    var products: [SKProduct] { get }
    var requestRunning: Int { get }

    func requestProducts()
    func buyProduct(_ product: SKProduct)
    func buyProduct(_ productIdentifier: String)
    func appUsagePermitted() -> Bool
    func restorePurchases()
}

class IAPHelper: NSObject, IAPHelperDelegate, Logging {
    fileprivate static let productIdentifiers = Set(["DONATION_LEVEL1", "DONATION_LEVEL2", "DONATION_LEVEL3",
                                                     "SUBSCRIPTION_MONTHLY", "SUBSCRIPTION_YEARLY"])
    fileprivate var productsRequest = SKProductsRequest(productIdentifiers: IAPHelper.productIdentifiers)
    fileprivate var receiptRequest = SKReceiptRefreshRequest()

    var products = [SKProduct]() {
        didSet {
            self.onboardingVCDelegate?.updateGUI()
            self.donationPreferencesVCDelegate?.updateGUI()
        }
    }
    private var receipt: ParsedReceipt?
    var requestRunning: Int = 0 {
        didSet {
            self.onboardingVCDelegate?.updateGUI()
            self.donationPreferencesVCDelegate?.updateGUI()
        }
    }
    weak var onboardingVCDelegate: OnboardingVCDelegate?
    weak var donationPreferencesVCDelegate: DonationPreferencesVCDelegate?

    override init() {

        // initialize the superclass and add class to payment queue
        super.init()

        // set delegates
        self.productsRequest.delegate = self
        self.receiptRequest.delegate = self
        SKPaymentQueue.default().add(self)

        // request products and receipt
        self.requestProducts()
        #if RELEASE
        self.requestReceipt(appStart: true)
        #endif
    }

}

// MARK: - StoreKit API

extension IAPHelper {

    public func buyProduct(_ product: SKProduct) {
        os_log("Buying %@ ...", log: self.log, type: .info, product.productIdentifier)
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
        self.requestRunning += 1
    }

    public func buyProduct(_ productIdentifier: String) {
        for product in self.products where product.productIdentifier == productIdentifier {
            self.buyProduct(product)
            break
        }
    }

    public func requestProducts() {
        self.productsRequest.cancel()
        self.productsRequest.start()
        self.requestRunning += 1
    }

    public func restorePurchases() {

        if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL {
            do {
                try FileManager.default.removeItem(at: appStoreReceiptURL)
            } catch {
                os_log("Receipt could not be restored: %@", log: self.log, type: .error, error.localizedDescription)
            }
        }

        // restore subscriptions
        SKPaymentQueue.default().restoreCompletedTransactions()

        // request a new receipt
        // NOTE: this should be done by 'restoreCompletedTransactions()'
        //self.requestReceipt(forceRefresh: true)
    }

    public func appUsagePermitted() -> Bool {
        #if RELEASE
        guard let receipt = self.receipt else { return false }

        // test if the user has bought the app before the subscription model started
        if preSubscriptionPurchase() {
            return true
        }

        // test if the user is in a valid subscription
        for tempReceipt in receipt.inAppPurchaseReceipts ?? [] {

            if let productIdentifier = tempReceipt.productIdentifier,
                productIdentifier.hasPrefix("SUBSCRIPTION_"),
                let subscriptionExpirationDate = tempReceipt.subscriptionExpirationDate,
                subscriptionExpirationDate > Date() {

                // assume that there is a subscription with a valid expiration date
                os_log("Receipt expires: %@", log: self.log, type: .debug, subscriptionExpirationDate.description(with: .current))
                return true
            }
        }

        return false
        #else
        return true
        #endif
    }

    fileprivate func preSubscriptionPurchase() -> Bool {
        #if RELEASE
        guard let receipt = self.receipt,
            let originalAppVersion = receipt.originalAppVersion else { return false }

        return originalAppVersion == "1.0" ||
            originalAppVersion.hasPrefix("1.1.") ||
            originalAppVersion.hasPrefix("1.2.")
        #else
        return true
        #endif
    }

    fileprivate func validateReceipt() {
        // validate the receipt data
        let receiptValidator = ReceiptValidator()
        let validationResult = receiptValidator.validateReceipt()

        // handle the validation result
        switch validationResult {
        case .success(let receipt):
            os_log("Receipt validation: successful.", log: self.log, type: .info)
            self.receipt = receipt

        case .error(let error):
            os_log("Receipt validation: unsuccessful (%@)", log: self.log, type: .error, error.localizedDescription)
        }
    }

    fileprivate func requestReceipt(forceRefresh: Bool = false, appStart: Bool = false) {
        // refresh receipt if not reachable
        if let receiptUrl = Bundle.main.appStoreReceiptURL,
            let isReachable = try? receiptUrl.checkResourceIsReachable(),
            isReachable,
            forceRefresh == false {
            os_log("Receipt already found, skipping receipt refresh (isReachable: %@, forceRefresh: %@).", log: self.log, type: .info, isReachable.description, forceRefresh.description)
            self.validateReceipt()

        } else if appStart {
            os_log("Receipt not found, exit the app!", log: self.log, type: .error)
            exit(173)

        } else {
            os_log("Receipt not found, refreshing receipt.", log: self.log, type: .info)
            self.receiptRequest.cancel()
            self.receiptRequest.start()
            self.requestRunning += 1
        }
    }
}

// MARK: - SKProductsRequestDelegate

extension IAPHelper: SKProductsRequestDelegate {

    internal func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        self.products = response.products
        os_log("Loaded list of products...", log: self.log, type: .debug)

        // log the products
        for product in self.products {
            os_log("Found product: %@ - %@ - %@", log: self.log, type: .debug, product.productIdentifier, product.localizedTitle, product.localizedPrice)
        }
    }

    internal func request(_ request: SKRequest, didFailWithError error: Error) {
        os_log("Product Request errored: %@", log: self.log, type: .error, error.localizedDescription)
        self.requestRunning -= 1
    }
}

// MARK: - SKPaymentTransactionObserver

extension IAPHelper: SKPaymentTransactionObserver {

    internal func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                os_log("Payment completed.", log: self.log, type: .debug)
                SKPaymentQueue.default().finishTransaction(transaction)

                // validate the new receipt (from purchase)
                self.validateReceipt()

                // fire up a request finished notification
                self.requestRunning -= 1

                // finish transaction and close the onboarding view
                queue.finishTransaction(transaction)
                self.onboardingVCDelegate?.closeOnboardingView()
            case .failed:
                os_log("Payment failed.", log: self.log, type: .debug)
                self.requestRunning -= 1
            case .restored:
                os_log("Payment restored.", log: self.log, type: .debug)
                queue.finishTransaction(transaction)
            case .deferred:
                os_log("Payment deferred.", log: self.log, type: .debug)
            case .purchasing:
                os_log("In purchasing process.", log: self.log, type: .debug)
            }
        }
    }
}

// MARK: - SKRequestDelegate

extension IAPHelper: SKRequestDelegate {

    internal func requestDidFinish(_ request: SKRequest) {
        self.requestRunning -= 1

        if request is SKReceiptRefreshRequest {
            // validate and save the receipt
            self.validateReceipt()
        }
    }
}
