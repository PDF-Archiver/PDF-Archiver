//
//  OnboardSet.swift
//  Onboarding
//
//  Created by Stewart Lynch on 2020-06-27.
//

import DeveloperToolsSupport
import Foundation

struct OnboardSet {
    private(set) var cards: [OnboardCard] = []

    mutating func newCard(title: String, image: ImageResource, text: String) {
        cards.append(OnboardCard(title: title, image: image, text: text))
    }
}

#if DEBUG
extension OnboardSet {
    static func previewSet() -> OnboardSet {
        var onboardSet = OnboardSet()
        onboardSet.newCard(title: NSLocalizedString("intro.scan.title", bundle: .module, comment: "Intro: Scan Title"),
                           image: ImageResource.scanAsset,
                           text: NSLocalizedString("intro.scan.description", bundle: .module, comment: "Intro: Scan Description"))
        onboardSet.newCard(title: "Login", image: ImageResource.tag1Asset, text: "Enter your credentials and log in.")
        onboardSet.newCard(title: "Update Profile", image: ImageResource.scanAsset, text: "Make sure you update your profile and avatar.")
        onboardSet.newCard(title: "Participate", image: ImageResource.tag1Asset, text: "Engage with others online.  Join the community.")
        onboardSet.newCard(title: "Leave Feedback", image: ImageResource.scanAsset, text: "We want to hear from you so please let us know what you think.")
        onboardSet.newCard(title: "Your Data", image: ImageResource.tag1Asset, text: "Your data is your own.  View your stats at any time.")
        return onboardSet
    }
}
#endif
