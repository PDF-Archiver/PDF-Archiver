import Foundation
import StoreKit
import Testing

@testable import ArchiverFeatures

struct PremiumProductTests {
    @Test
    func lifetimeGrantsPremium() {
        #expect(PremiumProduct.grantsPremium(productType: .nonConsumable,
                                             productID: PremiumProduct.lifetime,
                                             subscriptionGroupID: nil,
                                             revocationDate: nil))
    }

    @Test
    func revokedLifetimeDoesNotGrantPremium() {
        #expect(!PremiumProduct.grantsPremium(productType: .nonConsumable,
                                              productID: PremiumProduct.lifetime,
                                              subscriptionGroupID: nil,
                                              revocationDate: Date()))
    }

    @Test
    func anySubscriptionInTheGroupGrantsPremium() {
        #expect(PremiumProduct.grantsPremium(productType: .autoRenewable,
                                             productID: "SOME_PRODUCT_NO_LONGER_ON_SALE",
                                             subscriptionGroupID: PremiumProduct.subscriptionGroupID,
                                             revocationDate: nil))
    }

    @Test
    func subscriptionInAnotherGroupDoesNotGrantPremium() {
        #expect(!PremiumProduct.grantsPremium(productType: .autoRenewable,
                                              productID: "SUBSCRIPTION_MONTHLY_IOS",
                                              subscriptionGroupID: "some-other-group",
                                              revocationDate: nil))
    }

    @Test
    func consumableDoesNotGrantPremium() {
        #expect(!PremiumProduct.grantsPremium(productType: .consumable,
                                              productID: PremiumProduct.lifetime,
                                              subscriptionGroupID: nil,
                                              revocationDate: nil))
    }

    @Test
    func nonRenewableDoesNotGrantPremium() {
        #expect(!PremiumProduct.grantsPremium(productType: .nonRenewable,
                                              productID: PremiumProduct.lifetime,
                                              subscriptionGroupID: nil,
                                              revocationDate: nil))
    }
}
