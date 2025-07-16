//
//  StatsView.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 16.07.25.
//

import Charts
import Shared
import SwiftUI

public struct StatsView: View {
    public enum Size {
        case small, medium, large
    }

    struct YearCount: Hashable {
        let year: Int
        let count: Int
    }

    public typealias Year = Int
    public typealias Count = Int
    let yearStats: [Year: Count]
    let size: Size

    public init(yearStats: [Year: Count], size: Size) {
        self.yearStats = yearStats
        self.size = size
    }

    public var body: some View {
        let yearStats = self.yearStats
            .map { YearCount(year: $0.key, count: $0.value) }
            .sorted { $0.year < $1.year }
            .reversed()
            .prefix(5)

        let maxCount = yearStats.map(\.count).max() ?? 1

        VStack(alignment: .leading) {

            HStack(alignment: .top) {
                Text("Documents per year")
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.primary)

                Spacer()

                Link(destination: DeepLink.scan.url) {
                    Image(systemName: "doc.viewfinder")
                }
                .padding(10)
                .background(Circle().fill(Color.paDarkRedAsset))
                .foregroundColor(.white)
            }

            Spacer()

            Chart(yearStats, id: \.self) { item in
                BarMark(
                    x: .value("Amount", item.count),
                    y: .value("Period", "\(item.year)")
                )
                .annotation(position: .leading) {
                    Text(item.year, format: .number.grouping(.never))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(Color.secondaryLabelAsset)
                }
                .annotation(position: .trailing) {
                    Text("\(item.count)")
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
                .foregroundStyle(Color.paDarkRedAsset.opacity(Double(item.count) / Double(maxCount)))
            }
            .frame(height: 80)
            .fixedSize(horizontal: false, vertical: true)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYAxis {
                AxisMarks(stroke: StrokeStyle(lineWidth: 0))
            }
            .chartXAxis {
                AxisMarks(stroke: StrokeStyle(lineWidth: 0))
            }
        }
    }
}

#Preview {
    Group {
        StatsView(yearStats: [
            2019: 3,
            2020: 7,
            2021: 5,
            2022: 8,
            2023: 10,
            2024: 6,
            2025: 15
        ],
                  size: .medium)
        StatsView(yearStats: [
            2022: 8,
            2023: 3,
            2024: 7,
            2025: 5
        ],
                  size: .medium)
        StatsView(yearStats: [
            2023: 133,
            2024: 89,
            2025: 50
        ],
                  size: .medium)
        StatsView(yearStats: [
            2024: 45,
            2025: 50
        ],
                  size: .medium)
        StatsView(yearStats: [
            2025: 50
        ],
                  size: .medium)
    }
    .padding()
}
