//
//  StatCard.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 04.10.25.
//

import Shared
import SwiftUI

struct StatCard<Value: View>: View {
    let title: String
    let systemImage: String
    let color: Color
    @ViewBuilder let value: () -> Value

    // The symbols differ in height; a shared row height keeps the values of all cards aligned.
    @ScaledMetric(relativeTo: .title2) private var iconHeight = 28.0

    init(
        title: String,
        systemImage: String,
        color: Color = .paRedAsset,
        @ViewBuilder value: @escaping () -> Value
    ) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.value = value
    }

    private var valueFont: Font {
        #if os(macOS)
        .largeTitle.bold()
        #else
        .title.bold()
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
                    .font(.title2)
                Spacer()
            }
            .frame(height: iconHeight)

            value()
                .font(valueFont)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .statisticsCard()
    }
}

extension View {
    func statisticsCard() -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.paSecondaryBackgroundAsset)
            )
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            StatCard(
                title: "Gesamt",
                systemImage: "doc.text.fill"
            ) {
                Text(1234, format: .number)
            }
            StatCard(
                title: "Speicher",
                systemImage: "internaldrive.fill"
            ) {
                Text(Int64(45_300_000), format: .byteCount(style: .file))
            }
        }

        HStack(spacing: 12) {
            StatCard(
                title: "Dieses Jahr",
                systemImage: "calendar"
            ) {
                Text(89, format: .number)
            }
            StatCard(
                title: "Tags",
                systemImage: "tag.fill"
            ) {
                Text(42, format: .number)
            }
        }
    }
    .padding()
}
