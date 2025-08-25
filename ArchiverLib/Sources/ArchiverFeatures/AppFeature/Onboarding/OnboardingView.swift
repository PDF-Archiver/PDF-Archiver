//
//  OnboardingView.swift
//  Onboarding
//
//  Created by Stewart Lynch on 2020-06-27.
//

import SwiftUI

 struct OnboardingView: View {
     init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    @Binding  var isPresented: Bool
    var onboardSet: OnboardSet = {
        var onboardSet = OnboardSet()
        onboardSet.newCard(title: NSLocalizedString("intro.scan.title", bundle: .module, comment: "Intro: Scan Title"),
                           image: "scan",
                           text: NSLocalizedString("intro.scan.description", bundle: .module, comment: "Intro: Scan Description"))
        onboardSet.newCard(title: NSLocalizedString("intro.tag.title", bundle: .module, comment: "Intro: Tag Title"),
                           image: "tag-1",
                           text: NSLocalizedString("intro.tag.description", bundle: .module, comment: "Intro: Tag Description"))
        onboardSet.newCard(title: NSLocalizedString("intro.find.title", bundle: .module, comment: "Intro: Find Title"),
                           image: "find",
                           text: NSLocalizedString("intro.find.description", bundle: .module, comment: "Intro: Find Description"))
        onboardSet.newCard(title: NSLocalizedString("intro.subscription.title", bundle: .module, comment: "Intro: Subscription Title"),
                           image: "piggy-bank",
                           text: NSLocalizedString("intro.subscription.description", bundle: .module, comment: "Intro: Subscription Description"))
        onboardSet.newCard(title: NSLocalizedString("intro.last.title", bundle: .module, comment: "Intro: Last Page Title"),
                           image: "start",
                           text: NSLocalizedString("intro.last.description", bundle: .module, comment: "Intro: Last Page Description"))
        return onboardSet
    }()
     var body: some View {
        OnboardingScreens(isPresented: $isPresented, onboardSet: onboardSet)
    }
}

#if DEBUG
#Preview {
    OnboardingView(isPresented: .constant(true))
}
#endif
