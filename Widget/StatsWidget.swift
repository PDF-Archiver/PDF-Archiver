//
//  StatsWidget.swift
//  Widget
//
//  Created by Julian Kahnert on 29.05.25.
//

import AppIntents
import Charts
import IntentLib
import SwiftData
import SwiftUI
import WidgetKit

struct StatsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StatsEntry {
        let configuration = ConfigurationAppIntent()
        let yearStats: [Int: Int] = [
            configuration.firstYear: 3,
            configuration.firstYear + 1: 7,
            configuration.firstYear + 2: 5
        ]
        return StatsEntry(date: Date(), yearStats: yearStats)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> StatsEntry {
        let configuration = ConfigurationAppIntent()

        let statistics = SharedDefaults.getStatistics()
        let yearStats = statistics.filter { $0.key >= configuration.firstYear }

        return StatsEntry(date: Date(), yearStats: yearStats)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<StatsEntry> {
        var entries: [StatsEntry] = []

        // we can only calculate the current state of the archive
        let entry = await snapshot(for: configuration, in: context)
        entries.append(entry)

        return Timeline(entries: entries, policy: .after(Date().advanced(by: 60 * 60 * 24)))    // 24h
    }
}

struct StatsEntry: TimelineEntry {
    let date: Date
    let yearStats: [Int: Int]   // year: count
}

struct WidgetStatsEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily

    struct YearCount: Hashable {
        let year: Int
        let count: Int
    }

    var entry: StatsProvider.Entry

    func color(for count: Int, max: Int) -> Color {
        let relative = Double(count) / Double(max)
        let brightness = 0.5 + (1 - relative) * 0.4  // Helle Werte bei kleinen Zahlen
        return Color(hue: 0, saturation: 0.1, brightness: brightness)
    }

    var body: some View {
        let yearStats = entry.yearStats
            .map { YearCount(year: $0.key, count: $0.value) }
            .sorted { $0.year < $1.year }
//            .reversed()
            .prefix(5)

        VStack(alignment: .leading) {
            
            Text("Documents per year")
                .minimumScaleFactor(0.8)
            
            Spacer()
            
            let maxCount = yearStats.map(\.count).max() ?? 1

            Chart {
                ForEach(Array(yearStats.enumerated()), id: \.element) { _, item in
                    BarMark(
                        x: .value("Amount", item.count),
                        stacking: .normalized
                    )
                    .foregroundStyle(color(for: item.count, max: maxCount))
//                    .cornerRadius(50)
                    .annotation(position: .overlay) {
                        Text("\(item.count)")
                            .font(.caption2)
                            .minimumScaleFactor(0.2)
                            .foregroundColor(.white)
                            .opacity(item.count > 0 ? 1 : 0.5)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .frame(height: 30)
            .chartLegend(position: .bottom, alignment: .center, spacing: 6)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            
            HStack(spacing: 0) {
                ForEach(Array(yearStats.enumerated()), id: \.element) { index, item in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(color(for: item.count, max: maxCount))
                            .frame(width: 8, height: 8)
                        Text(item.year.formatted(.number.grouping(.never)))
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            Spacer()

            Link(destination: DeepLink.scan.url) {
                Label("Scan", systemImage: "document.viewfinder")
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(
                        Capsule().fill(Color("paDarkRedAsset"))
                    )
                    .foregroundColor(.white)
            }
        }
    }
}

fileprivate extension View {
    @ViewBuilder
    func labelStyle(includingText: Bool) -> some View {
        if includingText {
            self.labelStyle(.titleAndIcon)
        } else {
            self.labelStyle(.iconOnly)
        }
    }
}

struct StatsWidget: Widget {
    let kind: String = "StatsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind,
                               intent: ConfigurationAppIntent.self,
                               provider: StatsProvider()) { entry in
            WidgetStatsEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("PDF Statistics")
        .description("Number of PDFs per year in your archive.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemMedium) {
    StatsWidget()
} timeline: {
    StatsEntry(date: .now, yearStats: [
        2022: 30,
        2022 + 1: 117,
        2022 + 2: 145,
        2022 + 3: 380,
        2022 + 4: 550
    ])
    StatsEntry(date: .now, yearStats: [
        2023: 433,
        2023 + 1: 700,
        2023 + 2: 10
    ])
    StatsEntry(date: .now, yearStats: [
        2024: 300,
        2024 + 1: 70,
        2024 + 2: 505
    ])
}
