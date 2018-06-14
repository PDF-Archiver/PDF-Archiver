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
        return formatter.string(from: price)!
    }
}
