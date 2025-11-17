//
//  TopTagsChart.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 04.10.25.
//

import ArchiverModels
import Charts
import Shared
import SwiftUI

public struct TopTagsChart: View {
    struct TagData: Identifiable {
        let id = UUID()
        let tag: String
        let count: Int
    }

    let tags: [TagCount]

    public init(tags: [TagCount]) {
        self.tags = tags
    }

    public var body: some View {
        let tagData = tags.prefix(5).map { TagData(tag: $0.tag, count: $0.count) }
        let maxCount = tagData.map(\.count).max() ?? 1

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text("Most Used Tags", bundle: #bundle)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.primary)

                Spacer()
            }

            if tagData.isEmpty {
                ContentUnavailableView(
                    String(localized: "No Tags", bundle: #bundle),
                    systemImage: "tag",
                    description: Text("Tag your documents to see the most used tags", bundle: #bundle)
                )
            } else {
                Chart(tagData) { item in
                    BarMark(
                        x: .value("Amount", item.count),
                        y: .value("Tag", item.tag)
                    )
                    .annotation(position: .trailing, spacing: 8) {
                        Text("\(item.count)")
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                    .foregroundStyle(
                        Color.paRedAsset.opacity(0.3 + (Double(item.count) / Double(maxCount) * 0.7))
                    )
                }
                .frame(height: CGFloat(tagData.count * 32))
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let tag = value.as(String.self) {
                                Text(tag)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        TopTagsChart(tags: [
            TagCount(tag: "rechnung", count: 45),
            TagCount(tag: "versicherung", count: 32),
            TagCount(tag: "vertrag", count: 28),
            TagCount(tag: "steuer", count: 21),
            TagCount(tag: "gehalt", count: 15)
        ])

        TopTagsChart(tags: [
            TagCount(tag: "rechnung", count: 5),
            TagCount(tag: "brief", count: 3)
        ])

        TopTagsChart(tags: [])
    }
    .padding()
}
