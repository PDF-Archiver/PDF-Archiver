//
//  PaywallPlanTests.swift
//  ArchiverLib
//

import StoreKit
import Testing

@testable import ArchiverFeatures

@Suite("Paywall plan call to action")
struct PaywallPlanTests {

    @Test("Lifetime buys for its price, even if a trial is passed")
    func lifetimeBuysForPrice() {
        let trial = FreeTrial(value: 2, unit: .week)
        #expect(PaywallPlan.lifetime.callToAction(displayPrice: "$26.99", freeTrial: trial) == .buyLifetime(price: "$26.99"))
    }

    @Test("A subscription with a free trial starts the trial", arguments: [PaywallPlan.yearly, .monthly])
    func subscriptionWithTrialStartsTrial(plan: PaywallPlan) {
        let trial = FreeTrial(value: 2, unit: .week)
        #expect(plan.callToAction(displayPrice: "$6.99", freeTrial: trial) == .startFreeTrial(trial))
    }

    @Test("A subscription without a free trial subscribes for its price", arguments: [PaywallPlan.yearly, .monthly])
    func subscriptionWithoutTrialSubscribes(plan: PaywallPlan) {
        #expect(plan.callToAction(displayPrice: "$1.99", freeTrial: nil) == .subscribe(price: "$1.99"))
    }

    @Test("An eligible free-trial offer becomes a trial")
    func eligibleFreeTrialOffer() {
        #expect(FreeTrial(paymentMode: .freeTrial, value: 2, unit: .week, isEligible: true) == FreeTrial(value: 2, unit: .week))
    }

    @Test("No trial when the account is not eligible")
    func ineligibleAccountGetsNoTrial() {
        #expect(FreeTrial(paymentMode: .freeTrial, value: 2, unit: .week, isEligible: false) == nil)
    }

    @Test("No trial when the intro offer is paid", arguments: [Product.SubscriptionOffer.PaymentMode.payAsYouGo, .payUpFront])
    func paidIntroOfferIsNoTrial(paymentMode: Product.SubscriptionOffer.PaymentMode) {
        #expect(FreeTrial(paymentMode: paymentMode, value: 1, unit: .month, isEligible: true) == nil)
    }

    @Test("No trial without an intro offer")
    func missingIntroOfferIsNoTrial() {
        #expect(FreeTrial(paymentMode: nil, value: 0, unit: .day, isEligible: true) == nil)
    }

    @Test("Lifetime is preselected and listed first")
    func lifetimeIsFirst() {
        #expect(PaywallPlan.allCases.first == .lifetime)
    }
}
