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

    var body: some View {
        let yearStats = entry.yearStats
            .map { YearCount(year: $0.key, count: $0.value) }
            .sorted { $0.year < $1.year }
            .reversed()
            .prefix(3)

        VStack(alignment: .leading) {
            Chart(yearStats, id: \.self) { item in
                BarMark(
                    x: .value("Amount", item.count),
                    y: .value("Period", "\(item.year)")
                )
                .annotation(position: .trailing) {
                    Text("\(item.count)")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(stroke: StrokeStyle(lineWidth: 0))
            }
            .chartXAxis {
                AxisMarks(stroke: StrokeStyle(lineWidth: 0))
            }

            HStack {
                Spacer()
                Link(destination: DeepLink.scan.url) {
                    Label("Scan", systemImage: "document.viewfinder")
                        .labelStyle(includingText: widgetFamily == .systemMedium)
                        .padding(10)
                        .background(ContainerRelativeShape().fill(Color.gray.opacity(0.3)))
                }
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
        2022: 3,
        2022 + 1: 7,
        2022 + 2: 5,
        2022 + 3: 8,
        2022 + 4: 10
    ])
    StatsEntry(date: .now, yearStats: [
        2023: 3,
        2023 + 1: 7,
        2023 + 2: 5
    ])
    StatsEntry(date: .now, yearStats: [
        2024: 3,
        2024 + 1: 7,
        2024 + 2: 5
    ])
}
