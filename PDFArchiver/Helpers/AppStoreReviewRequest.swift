//
//  AppStoreReviewRequest.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 23.09.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//
//  Inspired by: https://developer.apple.com/documentation/storekit/skstorereviewcontroller/requesting_app_store_reviews
//

import Foundation
import StoreKit.SKStoreReviewController
import AppKit.NSWorkspace

private enum UserDefaultsKeys: String {
    case processCompletedCountKey
    case lastVersionPromptedForReviewKey
}

final class AppStoreReviewRequest {

    static let shared = AppStoreReviewRequest()

    private var count: Int {
        didSet {
            UserDefaults.standard.set(self.count, forKey: UserDefaultsKeys.processCompletedCountKey.rawValue)
        }
    }
    private let currentVersion: String
    private let lastVersionPromptedForReview: String

    private init() {
        // Get the current bundle version for the app
        let infoDictionaryKey = kCFBundleVersionKey as String
        guard let currentVersion = Bundle.main.object(forInfoDictionaryKey: infoDictionaryKey) as? String
            else { fatalError("Expected to find a bundle version in the info dictionary") }
        self.currentVersion = currentVersion

        // get the last count and version from UserDefaults
        self.count = UserDefaults.standard.integer(forKey: UserDefaultsKeys.processCompletedCountKey.rawValue)
        self.lastVersionPromptedForReview = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastVersionPromptedForReviewKey.rawValue) ?? ""
    }

    private func isSameMajorMinorVersion(version1: String, version2: String) -> Bool {
        return version1.split(separator: ".").dropLast().joined(separator: ".") == version2.split(separator: ".").dropLast().joined(separator: ".")
    }

    public func incrementCount() {
        self.count += 1

        // Has the process been completed several times and the user has not already been prompted for this version?
        if self.count >= 4 && isSameMajorMinorVersion(version1: self.currentVersion, version2: self.lastVersionPromptedForReview) {
            let twoSecondsFromNow = DispatchTime.now() + 2.0
            DispatchQueue.main.asyncAfter(deadline: twoSecondsFromNow) {
                if #available(OSX 10.14, *) {
                    SKStoreReviewController.requestReview()
                    UserDefaults.standard.set(self.currentVersion, forKey: UserDefaultsKeys.lastVersionPromptedForReviewKey.rawValue)
                }
            }
        }
    }

    public func requestReviewManually(for appId: Int) {
        guard let writeReviewURL = URL(string: "macappstore://itunes.apple.com/app/id\(appId)?action=write-review")
            else { fatalError("Expected a valid URL") }
        NSWorkspace.shared.open(writeReviewURL)
    }
}
