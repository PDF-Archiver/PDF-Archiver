//
//  OBCardView.swift
//  Onboarding
//
//  Created by Stewart Lynch on 2020-06-27.
//

import SwiftUI

struct OBCardView: View {
    let currentCardIndex: Int
    let cardCount: Int
    let buttonTapped: () -> Void
    let card: OnboardCard
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(card.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 100, maxHeight: 100)
            Spacer()
            Text(card.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.paDarkRed)
                .multilineTextAlignment(.center)
            Text(card.text)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.9)
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    withAnimation {
                        buttonTapped()
                    }
                }) {
                    Image(systemName: (currentCardIndex + 1) == cardCount ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                        .resizable()
                        .padding(8)
                        .scaledToFit()
                        .font(.largeTitle)

                }
                .frame(width: 50, height: 50)
                .padding()
                .buttonStyle(BorderlessButtonStyle())
            }
        }
    }

    private var progressView: some View {
        HStack {
            ForEach(0..<cardCount) { i in
                Circle()
                    .scaledToFit()
                    .frame(width: 10)
                    .foregroundColor(currentCardIndex >= i ? Color.accentColor : Color(.systemGray))
            }
        }
    }
}

#if DEBUG
struct OBCardView_Previews: PreviewProvider {
    static let onboardSet = OnboardSet.previewSet()
    static var previews: some View {
        Group {
            OBCardView(currentCardIndex: 0, cardCount: 1, buttonTapped: {}, card: onboardSet.cards[0])
                .previewDevice("Mac")
            OBCardView(currentCardIndex: 1, cardCount: 1, buttonTapped: {}, card: onboardSet.cards[0])
                .makeForPreviewProvider()
        }
    }
}
#endif
