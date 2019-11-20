//
//  Notification.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation

extension Notification.Name {
    static let documentChanges = Notification.Name("document-changes")
    static let introChanges = Notification.Name("intro-changes")
    static let subscriptionChanges = Notification.Name("subscription-changes")
    static let showSubscriptionView = Notification.Name("show-subscription-view")
    static let showError = Notification.Name("show-error")
}

extension Notification {
    static let documentChanges = Notification(name: .documentChanges)
    static let introChanges = Notification(name: .introChanges)
    static let subscriptionChanges = Notification(name: .subscriptionChanges)
    static let showSubscriptionView = Notification(name: .showSubscriptionView)
    static let showError = Notification(name: .showError)
}
