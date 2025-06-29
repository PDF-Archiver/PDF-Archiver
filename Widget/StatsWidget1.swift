//
//  StatsWidget1.swift
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

struct StatsProvider1: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StatsEntry1 {
        let configuration = ConfigurationAppIntent()
        let yearStats: [Int: Int] = [
            configuration.firstYear: 3,
            configuration.firstYear + 1: 7,
            configuration.firstYear + 2: 5
        ]
        return StatsEntry1(date: Date(), yearStats: yearStats)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> StatsEntry1 {
        let configuration = ConfigurationAppIntent()

        let statistics = SharedDefaults.getStatistics()
        let yearStats = statistics.filter { $0.key >= configuration.firstYear }

        return StatsEntry1(date: Date(), yearStats: yearStats)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<StatsEntry1> {
        var entries: [StatsEntry1] = []

        // we can only calculate the current state of the archive
        let entry = await snapshot(for: configuration, in: context)
        entries.append(entry)

        return Timeline(entries: entries, policy: .after(Date().advanced(by: 60 * 60 * 24)))    // 24h
    }
}

struct StatsEntry1: TimelineEntry {
    let date: Date
    let yearStats: [Int: Int]   // year: count
}

struct WidgetStatsEntryView1: View {
    @Environment(\.widgetFamily) var widgetFamily

    struct YearCount: Hashable {
        let year: Int
        let count: Int
    }

    var entry: StatsProvider1.Entry

    var body: some View {
        let yearStats = entry.yearStats
            .map { YearCount(year: $0.key, count: $0.value) }
            .sorted { $0.year < $1.year }
            .reversed()
            .prefix(5)
        
        let maxCount = yearStats.map(\.count).max() ?? 1

        VStack(alignment: .leading) {
            
            HStack(alignment: .top) {
                Text("Documents per year")
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(Color(.black))
                
                Spacer()
                
                Link(destination: DeepLink.scan.url) {
                    Image(systemName: "doc.viewfinder")
                }
                .padding(10)
                .background(Circle().fill(Color("paDarkRedAsset")))
                .foregroundColor(Color(.white))
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
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .annotation(position: .trailing) {
                    Text("\(item.count)")
                        .font(.caption)
                        .foregroundStyle(Color(.black))
                }
                .foregroundStyle(Color("paDarkRedAsset").opacity(Double(item.count) / Double(maxCount)))
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
//        .background(Color.yellow.opacity(0.2)) // SafeArea coloring
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

struct StatsWidget1: Widget {
    let kind: String = "StatsWidget1"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind,
                               intent: ConfigurationAppIntent.self,
                               provider: StatsProvider1()) { entry in
            WidgetStatsEntryView1(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("PDF Statistics")
        .description("Number of PDFs per year in your archive.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemMedium) {
    StatsWidget1()
} timeline: {
    StatsEntry1(date: .now, yearStats: [
        2019: 3,
        2020: 7,
        2021: 5,
        2022: 8,
        2023: 10,
        2024: 6,
        2025: 15
        
    ])
    StatsEntry1(date: .now, yearStats: [
        2022: 8,
        2023: 3,
        2024: 7,
        2025: 5
    ])
    StatsEntry1(date: .now, yearStats: [
        2023: 133,
        2024: 89,
        2025: 50
    ])
    StatsEntry1(date: .now, yearStats: [
        2024: 45,
        2025: 50
    ])
    StatsEntry1(date: .now, yearStats: [
        2025: 50
    ])
}
