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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
                    .font(.title2)
                Spacer()
            }

            value()
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
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
