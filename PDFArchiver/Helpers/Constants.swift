//
//  Constants.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 09.07.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation
import Quartz

struct Constants {
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

    struct  Layout {
        static let wantsLayer = true
        static let cornerRadius = CGFloat(3)
        static let customViewBackground = NSColor(named: "DarkGreyBlue")!.withAlphaComponent(0.1).cgColor
        static let pdfViewBackground = NSColor(named: "DarkGrey")!
        static let mainViewBackground = NSColor(named: "OffWhite")!.cgColor
    }
}
