//
//  UserDefaultds.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 10.08.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation

extension UserDefaults {

    private enum Names: String {
        case tutorialShown = "tutorial-v1"
        case lastSelectedTabIndex
        case pdfQuality
        case subscriptionExpiryDate = "SubscriptionExpiryDate"
    }

    enum PDFQuality: Float, CaseIterable {
        case lossless = 1.0
        case good = 0.75
        case normal = 0.5
        case small = 0.25

        static let defaultQualityIndex = 1  // e.g. "good"

        static func toIndex(_ quality: PDFQuality) -> Int {
            let allCases = UserDefaults.PDFQuality.allCases
            return allCases.firstIndex(of: quality) ?? defaultQualityIndex
        }
    }

    var tutorialShown: Bool {
        get {
            return UserDefaults.standard.bool(forKey: Names.tutorialShown.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Names.tutorialShown.rawValue)
        }
    }

    var lastSelectedTabIndex: Int {
        get {
            return UserDefaults.standard.integer(forKey: Names.lastSelectedTabIndex.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Names.lastSelectedTabIndex.rawValue)
        }
    }

    var pdfQuality: PDFQuality {
        get {
            var value = UserDefaults.standard.float(forKey: Names.pdfQuality.rawValue)

            // set default to 0.75
            if value == 0.0 {
                value = PDFQuality.allCases[PDFQuality.defaultQualityIndex].rawValue
            }

            guard let level = PDFQuality(rawValue: value) else { fatalError("Could not parse level from value \(value).") }
            return level
        }
        set {
            Log.send(.info, "PDF Quality Changed.", extra: ["quality": String(newValue.rawValue)])
            UserDefaults.standard.set(newValue.rawValue, forKey: Names.pdfQuality.rawValue)
        }
    }

    var subscriptionExpiryDate: Date? {
        get {
            return UserDefaults.standard.object(forKey: Names.subscriptionExpiryDate.rawValue) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Names.subscriptionExpiryDate.rawValue)

        }
    }
}
