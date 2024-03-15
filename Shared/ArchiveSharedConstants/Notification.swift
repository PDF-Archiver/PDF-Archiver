//
//  Notification.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation

public extension Notification.Name {
    static let introChanges = Notification.Name("intro-changes")
    static let imageProcessingQueue = Notification.Name("ImageConverter.queueLength")
    static let showSubscriptionView = Notification.Name("show-subscription-view")
    static let suggestionChange = Notification.Name("suggestion-change")
    static let foundProcessedDocument = Notification.Name("found-processed-document")
    static let showSendDiagnosticsReport = Notification.Name("show-send-diagnostics-report")
}

public extension Notification {
    static let introChanges = Notification(name: .introChanges)
    static let showSubscriptionView = Notification(name: .showSubscriptionView)
    static let suggestionChange = Notification(name: .suggestionChange)
    static let foundProcessedDocument = Notification(name: .foundProcessedDocument)
}
