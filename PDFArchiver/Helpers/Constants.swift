//
//  Constants.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 09.07.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

class Constants {
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
}
