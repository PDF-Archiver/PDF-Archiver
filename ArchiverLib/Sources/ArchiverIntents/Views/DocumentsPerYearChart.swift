//
//  DocumentsPerYearChart.swift
//  ArchiverLib
//

import Charts
import Shared
import SwiftUI

public struct DocumentsPerYearChart: View {
    struct YearCount: Hashable {
        let year: String
        let count: Int
    }

    let yearStats: [Int: Int]

    public init(yearStats: [Int: Int]) {
        self.yearStats = yearStats
    }

    public var body: some View {
        // A string year keeps the axis categorical: one bar per year, no "2.024" digit grouping.
        let years = yearStats
            .sorted { $0.key < $1.key }
            .map { YearCount(year: String($0.key), count: $0.value) }
        let latestYear = years.last?.year

        VStack(alignment: .leading, spacing: 12) {
            Text("Documents per year", bundle: #bundle)
                .foregroundStyle(.primary)

            if years.isEmpty {
                ContentUnavailableView(
                    String(localized: "No Documents", bundle: #bundle),
                    systemImage: "document",
                    description: Text("Start adding documents to see your yearly statistics", bundle: #bundle)
                )
            } else {
                Chart(years, id: \.year) { item in
                    BarMark(
                        x: .value("Year", item.year),
                        y: .value("Amount", item.count)
                    )
                    .foregroundStyle(Color.paRedAsset.opacity(item.year == latestYear ? 1 : 0.6))
                }
                .chartXAxis {
                    AxisMarks {
                        // Drops labels that would overlap, e.g. 17 years on an iPhone.
                        AxisValueLabel(collisionResolution: .greedy)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let count = value.as(Int.self) {
                                Text(count, format: .number)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .frame(height: 240)
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        DocumentsPerYearChart(
            yearStats: Dictionary(uniqueKeysWithValues: (2008...2026).map { ($0, ($0 * 37) % 300 + 20) })
        )
        DocumentsPerYearChart(yearStats: [2024: 45, 2025: 50, 2026: 12])
        DocumentsPerYearChart(yearStats: [:])
    }
    .padding()
}
