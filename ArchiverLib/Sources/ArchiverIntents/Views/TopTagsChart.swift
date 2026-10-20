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
    let tags: [TagCount]

    public init(tags: [TagCount]) {
        self.tags = tags
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Most Used Tags", bundle: #bundle)
                .foregroundStyle(.primary)

            if tags.isEmpty {
                ContentUnavailableView(
                    String(localized: "No Tags", bundle: #bundle),
                    systemImage: "tag",
                    description: Text("Tag your documents to see the most used tags", bundle: #bundle)
                )
            } else {
                Chart(tags, id: \.tag) { item in
                    BarMark(
                        x: .value("Amount", item.count),
                        y: .value("Tag", item.tag)
                    )
                    .foregroundStyle(Color.paRedAsset)
                    .annotation(position: .trailing, spacing: 6) {
                        Text(item.count, format: .number)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    // `.extended` keeps the names left of the bars; the default puts long ones above.
                    AxisMarks(preset: .extended, position: .leading) {
                        AxisValueLabel()
                    }
                }
                .frame(height: CGFloat(tags.count) * 24)
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        TopTagsChart(tags: [
            TagCount(tag: "rechnung", count: 1228),
            TagCount(tag: "vanessa", count: 375),
            TagCount(tag: "versicherung", count: 355),
            TagCount(tag: "gemeinsames", count: 249),
            TagCount(tag: "haus", count: 247),
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
