//
//  Constants.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 09.07.18.
//  Copyright © 2020 Julian Kahnert. All rights reserved.
//
// swiftlint:disable force_unwrapping

import Foundation
import Quartz

enum Constants {
    static let appId: Int = 1352719750
    static let appURL: String = "https://pdf-archiver.io"
    static let donationCount = URL(string: appURL + "/assets/donations.txt")!
    static let manageSubscription = URL(string: "https://apps.apple.com/account/subscriptions")!

    enum WebsiteEndpoints: String {
        case faq
        case privacy
        case imprint

        var url: URL {
            return URL(string: "\(Constants.appURL)/\(self.rawValue)")!
        }
    }

    enum Layout {
        static let wantsLayer = true
        static let cornerRadius = CGFloat(3)
    }
}
