//
//  Extensions.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 14.06.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa
import StoreKit

// get filetype (e.g. of a picture aka "public.jpeg")
extension URL {
    var typeIdentifier: String? {
        return (try? resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier
    }
}

// localized price in SKProduct
extension SKProduct {
    var localizedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = priceLocale
        return formatter.string(from: price) ?? ""
    }
}

// remove document from array
extension Array where Element: NSObject {

    @discardableResult
    mutating func remove(_ element: Element) -> Element? {
        if let idx = self.index(of: element) {
            return self.remove(at: idx)
        } else {
            return nil
        }
    }

}

// add logging
import os.log

protocol Logging {
    var log: OSLog { get }
}

extension Logging {
    internal var log: OSLog {
        return OSLog(subsystem: Bundle.main.bundleIdentifier ?? "App",
                     category: String(describing: type(of: self)))
    }
}
