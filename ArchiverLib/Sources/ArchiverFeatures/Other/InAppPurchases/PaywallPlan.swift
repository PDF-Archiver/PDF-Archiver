//
//  PaywallPlan.swift
//  ArchiverLib
//

import StoreKit

/// A plan card of the paywall, in display order.
enum PaywallPlan: CaseIterable, Identifiable {
    case lifetime
    case yearly
    case monthly

    var id: Self { self }

    var productID: String {
        switch self {
        case .lifetime: return PremiumProduct.lifetime
        case .yearly: return PremiumProduct.yearly
        case .monthly: return PremiumProduct.monthly
        }
    }

    func callToAction(displayPrice: String, freeTrial: FreeTrial?) -> PaywallCallToAction {
        guard self != .lifetime else { return .buyLifetime(price: displayPrice) }
        guard let freeTrial else { return .subscribe(price: displayPrice) }
        return .startFreeTrial(freeTrial)
    }
}

enum PaywallCallToAction: Equatable {
    case buyLifetime(price: String)
    case startFreeTrial(FreeTrial)
    case subscribe(price: String)
}

/// The free introductory period a subscription grants this Apple Account.
struct FreeTrial: Equatable {
    let value: Int
    let unit: Product.SubscriptionPeriod.Unit

    init(value: Int, unit: Product.SubscriptionPeriod.Unit) {
        self.value = value
        self.unit = unit
    }

    /// Paid intro offers are not a trial, and an account that already used one gets the regular price.
    init?(paymentMode: Product.SubscriptionOffer.PaymentMode?,
          value: Int,
          unit: Product.SubscriptionPeriod.Unit,
          isEligible: Bool) {
        guard paymentMode == .freeTrial, isEligible else { return nil }
        self.init(value: value, unit: unit)
    }
}
