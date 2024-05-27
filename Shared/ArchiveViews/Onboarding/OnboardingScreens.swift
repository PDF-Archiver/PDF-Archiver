//
//  OnboardingScreens.swift
//  Onboarding
//
//  Created by Stewart Lynch on 2020-06-27.
//

import SwiftUI

struct OnboardingScreens: View {
    @Binding var isPresenting: Bool
    @State private var gesture: CGSize = .zero
    @State private var cardIndex = 0

    let onboardSet: OnboardSet
    var body: some View {
        VStack {
            OBCardView(card: onboardSet.cards[cardIndex])
                .padding(.top, 25)
         
            Spacer()
            progressView
            HStack {
                Spacer()
                Button(action: {
                    withAnimation {
                        showNextHandler()
                    }
                }) {
                    Image(systemName: (cardIndex + 1) == onboardSet.cards.count ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                        .font(.system(size: 40))
                }
                .buttonStyle(BorderlessButtonStyle())
                .focusable(false)
            }
        }
        .padding()
    }
    
    private var progressView: some View {
        HStack {
            ForEach(0..<onboardSet.cards.count, id: \.self) { index in
                Circle()
                    .frame(width: 10)
                    .foregroundColor(cardIndex >= index ? Color.paLightGray : Color(.tertiaryLabelColor))
            }
        }
    }

    private func showNextHandler() {
        let nextIndex = cardIndex + 1
        if nextIndex < onboardSet.cards.count {
            cardIndex = nextIndex
        } else {
            isPresenting = false
        }
    }
}

#if DEBUG
struct OnboardingScreens_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingScreens(isPresenting: .constant(true), onboardSet: OnboardSet.previewSet())
//            .makeForPreviewProvider()
            .previewDevice("Mac")
    }
}
#endif
