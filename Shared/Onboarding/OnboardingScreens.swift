//
//  OnboardingScreens.swift
//  Onboarding
//
//  Created by Stewart Lynch on 2020-06-27.
//

import SwiftUI

struct OnboardingScreens: View {
    @Binding var isPresenting: Bool
    @State private var cardIndex = 0

    let onboardSet: OnboardSet
    var body: some View {
        OBCardView(card: onboardSet.cards[cardIndex])
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            progressView
                .padding(.bottom)
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                withAnimation {
                    showNextHandler()
                }
            } label: {
                Image(systemName: (cardIndex + 1) == onboardSet.cards.count ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                    .font(.system(size: 40))
            }
            .buttonStyle(BorderlessButtonStyle())
            .focusable(false)
        }
        .padding()
    }

    private var progressView: some View {
        HStack {
            ForEach(0..<onboardSet.cards.count, id: \.self) { index in
                Circle()
                    .frame(width: 10)
                #if os(macOS)
                    .foregroundColor(cardIndex >= index ? Color.paLightGray : Color(.tertiaryLabelColor))
                #else
                    .foregroundColor(cardIndex >= index ? Color.paLightGray : Color(.tertiaryLabel))
                #endif
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
#Preview {
    OnboardingScreens(isPresenting: .constant(true), onboardSet: OnboardSet.previewSet())
}
#endif
