//
//  PremiumProduct.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import Foundation
import StoreKit

/// The product identifiers and the single rule for what grants premium.
enum PremiumProduct {
    static let subscriptionGroupID = "20516661"
    static let lifetime = "LIFETIME"
    /// Display order in `IAPView`.
    static let subscriptions = ["SUBSCRIPTION_YEARLY_IOS_NEW", "SUBSCRIPTION_MONTHLY_IOS"]

    /// The lifetime purchase or any subscription of the group grants premium. Matching the group
    /// instead of the product IDs keeps subscribers of products no longer on sale entitled.
    static func grantsPremium(productType: Product.ProductType,
                              productID: String,
                              subscriptionGroupID: String?,
                              revocationDate: Date?) -> Bool {
        guard revocationDate == nil else { return false }
        switch productType {
        case .nonConsumable: return productID == lifetime
        case .autoRenewable: return subscriptionGroupID == Self.subscriptionGroupID
        default: return false
        }
    }
}
