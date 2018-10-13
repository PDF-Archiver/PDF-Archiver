//
//  AppStoreReviewRequest.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 23.09.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//
//  Inspired by: https://developer.apple.com/documentation/storekit/skstorereviewcontroller/requesting_app_store_reviews
//

import AppKit.NSWorkspace
import Foundation
import StoreKit.SKStoreReviewController

private enum UserDefaultsKeys: String {
    case processCompletedCountKey
    case lastVersionPromptedForReviewKey
}

public final class AppStoreReviewRequest {

    static let shared = AppStoreReviewRequest()
    private let currentVersion: String

    private var count: Int {
        didSet {
            UserDefaults.standard.set(self.count, forKey: UserDefaultsKeys.processCompletedCountKey.rawValue)
        }
    }
    private var lastVersionPromptedForReview: String {
        didSet {
            UserDefaults.standard.set(self.lastVersionPromptedForReview, forKey: UserDefaultsKeys.lastVersionPromptedForReviewKey.rawValue)
        }
    }

    private init() {
        // Get the current bundle version for the app
        guard let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
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
        if isSameMajorMinorVersion(version1: self.currentVersion, version2: self.lastVersionPromptedForReview) {
            return
        }
        self.count += 1

        // Has the process been completed several times and the user has not already been prompted for this version?
        if self.count >= 5 {
            let twoSecondsFromNow = DispatchTime.now() + 2.0
            DispatchQueue.main.asyncAfter(deadline: twoSecondsFromNow) {
                if #available(OSX 10.14, *) {
                    SKStoreReviewController.requestReview()
                    self.lastVersionPromptedForReview = self.currentVersion
                    self.count = 0
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
