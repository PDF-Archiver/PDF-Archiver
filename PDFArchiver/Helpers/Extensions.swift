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

// slugify a string
extension String {
    func slugify(withSeparator separator: String = "-") -> String {
        // this function is inspired by:
        // https://github.com/malt03/SwiftString/blob/0aeb47cbfa77cf8552bbadf49360ef529fbb8c03/Sources/StringExtensions.swift#L194
        let slugCharacterSet = NSCharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789\(separator)")
        return replacingOccurrences(of: "ß", with: "ss")
            .replacingOccurrences(of: "Ä", with: "Ae")
            .replacingOccurrences(of: "Ö", with: "Oe")
            .replacingOccurrences(of: "Ü", with: "Ue")
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
            .folding(options: .diacriticInsensitive, locale: .current)
            .components(separatedBy: slugCharacterSet.inverted)
            .filter { $0 != "" }
            .joined(separator: separator)
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
        return OSLog(subsystem: Bundle.main.bundleIdentifier!,
                     category: String(describing: type(of: self)))
    }
}
