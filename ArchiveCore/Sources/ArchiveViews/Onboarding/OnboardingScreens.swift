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
        GeometryReader { proxy in
            ZStack(alignment: .center) {
                ForEach(0..<onboardSet.cards.count, id: \.self) { index in
                    OBCardView(currentCardIndex: index, cardCount: onboardSet.cards.count, buttonTapped: showNextHandler, card: onboardSet.cards[index])
                        .padding()
                        .frame(maxWidth: min(500, proxy.size.width * 0.85), maxHeight: proxy.size.height * 0.66)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.secondarySystemBackground)
                                        .shadow(radius: 10))
                        // Source: https://github.com/AugustDev/swiftui-onboarding-slider/blob/59b4d81e9b5606c2ad9b9868a79a1e2d386282b7/Onboarding/OnboardingViewPure.swift#L11
                        .offset(x: CGFloat(index) * proxy.size.width)
                        .offset(x: gesture.width - CGFloat(cardIndex) * proxy.size.width)
                        .animation(.spring())
                        .gesture(DragGesture().onChanged { value in
                            gesture = value.translation
                        }
                        .onEnded { _ in
                            if gesture.width < -50,
                               cardIndex < onboardSet.cards.count - 1 {
                                withAnimation {
                                    cardIndex += 1
                                }
                            } else if gesture.width > 50,
                                      cardIndex > 0 {
                                withAnimation {
                                    cardIndex -= 1
                                }
                            }
                            gesture = .zero
                        })
                }
            }
            .frame(width: proxy.frame(in: .global).width,
                   height: proxy.frame(in: .global).height)
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
