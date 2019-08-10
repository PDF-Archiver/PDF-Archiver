//
//  UserDefaultds.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 10.08.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation

extension UserDefaults {

    enum Names: String {
        case tutorialShown = "tutorial-v1"
        case lastSelectedTabIndex
        case pdfQuality
    }

    enum PDFQuality: Float, CaseIterable {
        case lossless = 1.0
        case good = 0.75
        case normal = 0.5
        case small = 0.25
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
                value = 0.75
            }

            guard let level = PDFQuality(rawValue: value) else { fatalError("Could not parse level from value \(value).") }
            return level
        }
        set {
            Log.info("PDF Quality Changed.", extra: ["quality": newValue.rawValue])
            UserDefaults.standard.set(newValue.rawValue, forKey: Names.pdfQuality.rawValue)
        }
    }
}
