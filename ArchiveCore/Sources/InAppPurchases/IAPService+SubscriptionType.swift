//
//  IAPService+SubscriptionType.swift
//  
//
//  Created by Julian Kahnert on 30.10.20.
//

extension IAPService {
    public enum SubscriptionType: String, CaseIterable {
        case monthly = "SUBSCRIPTION_MONTHLY_IOS"
        case yearly = "SUBSCRIPTION_YEARLY_IOS_NEW"
    }
}
