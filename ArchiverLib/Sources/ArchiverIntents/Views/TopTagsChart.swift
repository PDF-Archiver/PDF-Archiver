//
//  TopTagsChart.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 04.10.25.
//

import Charts
import Shared
import SwiftUI

public struct TopTagsChart: View {
    struct TagData: Identifiable {
        let id = UUID()
        let tag: String
        let count: Int
    }

    let tags: [(tag: String, count: Int)]

    public init(tags: [(tag: String, count: Int)]) {
        self.tags = tags
    }

    public var body: some View {
        let tagData = tags.prefix(5).map { TagData(tag: $0.tag, count: $0.count) }
        let maxCount = tagData.map(\.count).max() ?? 1

        VStack(alignment: .leading, spacing: 12) {
            if tagData.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tag.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Keine Tags gefunden")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
            } else {
                Chart(tagData) { item in
                    BarMark(
                        x: .value("Anzahl", item.count),
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
            ("rechnung", 45),
            ("versicherung", 32),
            ("vertrag", 28),
            ("steuer", 21),
            ("gehalt", 15)
        ])

        TopTagsChart(tags: [
            ("rechnung", 5),
            ("brief", 3)
        ])

        TopTagsChart(tags: [])
    }
    .padding()
}
