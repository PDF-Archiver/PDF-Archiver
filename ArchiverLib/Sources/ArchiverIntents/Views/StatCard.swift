//
//  StatCard.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 04.10.25.
//

import Shared
import SwiftUI

public struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    public init(title: String, value: String, systemImage: String, color: Color = .paRedAsset) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.color = color
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
                    .font(.title2)
                Spacer()
            }

            Text(value)
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
                value: "1.234",
                systemImage: "doc.text.fill"
            )
            StatCard(
                title: "Speicher",
                value: "45,3 MB",
                systemImage: "internaldrive.fill"
            )
        }

        HStack(spacing: 12) {
            StatCard(
                title: "Dieses Jahr",
                value: "89",
                systemImage: "calendar"
            )
            StatCard(
                title: "Tags",
                value: "42",
                systemImage: "tag.fill"
            )
        }
    }
    .padding()
}
