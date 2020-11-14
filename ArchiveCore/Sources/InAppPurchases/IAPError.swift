//
//  IAPError.swift
//  
//
//  Created by Julian Kahnert on 28.10.20.
//

import Foundation

public enum IAPError: String, LocalizedError {
    case purchaseFailedProductNotFound

    public var errorDescription: String? {
        switch self {
            case .purchaseFailedProductNotFound:
                return NSLocalizedString("Purchase failed, because no subscription could be found.", comment: "")
        }
    }
}
