//
//  StatsWidget.swift
//  Widget
//
//  Created by Julian Kahnert on 29.05.25.
//

import AppIntents
import ArchiverIntents
import Charts
import Shared
import SwiftData
import SwiftUI
import WidgetKit

@MainActor
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

extension StatsView.Size {
    static func create(from size: WidgetFamily) -> Self {
        switch size {
        case .systemSmall:
            return .small
        case .systemMedium:
            return .medium
        case .systemLarge, .systemExtraLarge:
            return .large
        default:
            return .small
        }
    }
}

struct StatsWidget: Widget {
    @Environment(\.widgetFamily) var widgetFamily
    let kind: String = "StatsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind,
                               intent: ConfigurationAppIntent.self,
                               provider: StatsProvider()) { entry in
            StatsView(yearStats: entry.yearStats,
                      size: .create(from: widgetFamily))
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
        2019: 3,
        2020: 7,
        2021: 5,
        2022: 8,
        2023: 10,
        2024: 6,
        2025: 15
    ])
    StatsEntry(date: .now, yearStats: [
        2022: 8,
        2023: 3,
        2024: 7,
        2025: 5
    ])
    StatsEntry(date: .now, yearStats: [
        2023: 133,
        2024: 89,
        2025: 50
    ])
    StatsEntry(date: .now, yearStats: [
        2024: 45,
        2025: 50
    ])
    StatsEntry(date: .now, yearStats: [
        2025: 50
    ])
}
