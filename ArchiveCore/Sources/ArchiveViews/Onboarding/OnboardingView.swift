//
//  OnboardingView.swift
//  Onboarding
//
//  Created by Stewart Lynch on 2020-06-27.
//

import SwiftUI

public struct OnboardingView: View {
    public init(isPresenting: Binding<Bool>) {
        self._isPresenting = isPresenting
    }

    @Binding public var isPresenting: Bool
    var onboardSet: OnboardSet = {
        let onboardSet = OnboardSet()
        onboardSet.newCard(title: NSLocalizedString("intro.scan.title", comment: "Intro: Scan Title"),
                           image: "scan",
                           text: NSLocalizedString("intro.scan.description", comment: "Intro: Scan Description"))
        onboardSet.newCard(title: NSLocalizedString("intro.tag.title", comment: "Intro: Tag Title"),
                           image: "tag-1",
                           text: NSLocalizedString("intro.tag.description", comment: "Intro: Tag Description"))
        onboardSet.newCard(title: NSLocalizedString("intro.find.title", comment: "Intro: Find Title"),
                           image: "find",
                           text: NSLocalizedString("intro.find.description", comment: "Intro: Find Description"))
        onboardSet.newCard(title: NSLocalizedString("intro.subscription.title", comment: "Intro: Subscription Title"),
                           image: "piggy-bank",
                           text: NSLocalizedString("intro.subscription.description", comment: "Intro: Subscription Description"))
        onboardSet.newCard(title: NSLocalizedString("intro.last.title", comment: "Intro: Last Page Title"),
                           image: "start",
                           text: NSLocalizedString("intro.last.description", comment: "Intro: Last Page Description"))
        return onboardSet
    }()
    public var body: some View {
        OnboardingScreens(isPresenting: $isPresenting, onboardSet: onboardSet)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isPresenting: .constant(false))
    }
}
