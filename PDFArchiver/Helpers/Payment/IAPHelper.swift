//
//  IAPHelper.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 22.06.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//  The structure is base on: https://www.raywenderlich.com/122144/in-app-purchase-tutorial
//

import StoreKit
import os.log

class IAPHelper: NSObject {
    fileprivate let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "IAPHelper")
    fileprivate let productIdentifiers: Set<String>
    fileprivate var productsRequest: SKProductsRequest
    fileprivate var receiptRequest = SKReceiptRefreshRequest()

    var products = [SKProduct]()
    var receipt: ParsedReceipt?

    override init() {
        self.productIdentifiers = Set(["DONATION_LEVEL1", "DONATION_LEVEL2", "DONATION_LEVEL3",
                                       "SUBSCRIPTION_MONTHLY", "SUBSCRIPTION_YEARLY"])
        self.productsRequest = SKProductsRequest(productIdentifiers: self.productIdentifiers)

        // initialize the superclass and add class to payment queue
        super.init()

        // set delegates
        self.productsRequest.delegate = self
        self.receiptRequest.delegate = self
        SKPaymentQueue.default().add(self)

        // request products and receipt
        self.requestProducts()
        self.requestReceipt()
    }

}

// MARK: - StoreKit API

extension IAPHelper {

    public func buyProduct(_ product: SKProduct) {
        os_log("Buying %@ ...", log: self.log, type: .info, product.productIdentifier)
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
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
    }

    public func appUsagePermitted() -> Bool {
        guard let receipt = self.receipt,
              let originalAppVersion = receipt.originalAppVersion else { return false }

        // test if the user has bought the app before the subscription model started
        if originalAppVersion == "1.0" ||
            originalAppVersion.hasPrefix("1.1.") ||
            originalAppVersion.hasPrefix("1.2.") {
            return true
        }

        // test if the user is in a valid subscription
        for receipt in (self.receipt?.inAppPurchaseReceipts)! {

            if let productIdentifier = receipt.productIdentifier,
                productIdentifier.hasPrefix("SUBSCRIPTION_"),
                let subscriptionExpirationDate = receipt.subscriptionExpirationDate,
                subscriptionExpirationDate > Date() {
                
                // assume that there is a subscription with a valid expiration date
                return true
            }
        }

        return false
    }

    fileprivate func validateReceipt() {
        let receiptValidator = ReceiptValidator()
        let validationResult = receiptValidator.validateReceipt()

        switch validationResult {
        case .success(let receipt):
            // Work with parsed receipt data. Possibilities might be...
            // enable a feature of your app
            // remove ads
            // etc...
            print("SUCCESS")
            print(receipt)
            self.receipt = receipt

        case .error(let error):
            // Handle receipt validation failure. Possibilities might be...
            // use StoreKit to request a new receipt
            // enter a "grace period"
            // disable a feature of your app
            // etc...
            print("ERROR:")
            print(error)
        }
    }

    fileprivate func requestReceipt(forceRefresh: Bool = false) {
        if let receiptUrl = Bundle.main.appStoreReceiptURL,
            let isReachable = try? receiptUrl.checkResourceIsReachable(),
            isReachable,
            forceRefresh == false {
            os_log("Receipt already found, skipping receipt refresh.", log: self.log, type: .info)
            self.validateReceipt()

        } else {
            os_log("Receipt not found, refreshing receipt.", log: self.log, type: .info)
            self.receiptRequest.cancel()
            self.receiptRequest.start()
        }
    }
}

// MARK: - SKProductsRequestDelegate

extension IAPHelper: SKProductsRequestDelegate {

    internal func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        self.products = response.products
        os_log("Loaded list of products...", log: self.log, type: .debug)

        // fire up a notification to update the GUI
        NotificationCenter.default.post(name: Notification.Name("MASUpdateStatus"), object: true)

        // log the products
        for product in self.products {
            os_log("Found product: %@ - %@ - %@", log: self.log, type: .debug, product.productIdentifier, product.localizedTitle, product.localizedPrice)
        }
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

                // show thanks message
                DispatchQueue.main.async {
                    dialogOK(messageKey: "payment_complete", infoKey: "payment_thanks", style: .informational)
                }
            case .failed:
                os_log("Payment failed.", log: self.log, type: .debug)
            case .restored:
                os_log("Payment restored.", log: self.log, type: .debug)
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
        if request is SKReceiptRefreshRequest {
            self.validateReceipt()
        }
    }
}
