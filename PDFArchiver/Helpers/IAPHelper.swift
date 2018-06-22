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
    fileprivate var productsRequest: SKProductsRequest?

    var products = [SKProduct]()

    public init(productIds: Set<String>) {
        self.productIdentifiers = productIds

        // initialize the superclass and add class to payment queue
        super.init()
        SKPaymentQueue.default().add(self)

        // get products
        self.productsRequest = SKProductsRequest(productIdentifiers: self.productIdentifiers)
        self.productsRequest!.delegate = self
        self.productsRequest!.start()
    }

}

// MARK: - StoreKit API

extension IAPHelper {

    public func requestProducts() {
        self.productsRequest?.cancel()

        self.productsRequest = SKProductsRequest(productIdentifiers: self.productIdentifiers)
        self.productsRequest!.delegate = self
        self.productsRequest!.start()
    }

    public func buyProduct(_ product: SKProduct) {
        os_log("Buying %@ ...", log: self.log, type: .info, product.productIdentifier)
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
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
