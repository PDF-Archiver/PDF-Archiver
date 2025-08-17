//
//  OBCardView.swift
//  Onboarding
//
//  Created by Stewart Lynch on 2020-06-27.
//

import Shared
import SwiftUI

struct OBCardView: View {
    let card: OnboardCard
    var body: some View {
        VStack(spacing: 8) {
            Image(card.image)
                .resizable()
                .scaledToFit()
                .frame(width: 75, height: 75)
                .padding(.bottom, 12)

            Text(card.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.paDarkRedAsset)
                .multilineTextAlignment(.center)
            Text(card.text)
                .foregroundColor(.paDarkGrayAsset)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#if DEBUG
let onboardSet = OnboardSet.previewSet()
#Preview("IAPView", traits: .fixedLayout(width: 400, height: 300)) {
    OBCardView(card: onboardSet.cards[0])
}

#Preview("IAPView Mac") {
    OBCardView(card: onboardSet.cards[0])
}
#endif
