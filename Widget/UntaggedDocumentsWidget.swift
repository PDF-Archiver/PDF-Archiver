//
//  UntaggedDocumentsWidget.swift
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
struct UntaggedDocumentsProvider: TimelineProvider {
    func placeholder(in context: Context) -> UntaggedDocumentsEntry {
        UntaggedDocumentsEntry(date: Date(), untaggedDocuments: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (UntaggedDocumentsEntry) -> Void) {
        let count = SharedDefaults.getUntaggedDocumentsCount()
        let entry = UntaggedDocumentsEntry(date: Date(), untaggedDocuments: count)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<UntaggedDocumentsEntry>) -> Void) {
        var entries: [UntaggedDocumentsEntry] = []

        // we can only calculate the current state of the archive
        let count = SharedDefaults.getUntaggedDocumentsCount()
        let entry = UntaggedDocumentsEntry(date: Date(), untaggedDocuments: count)
        entries.append(entry)

        let timeline = Timeline(entries: entries, policy: .after(Date().advanced(by: 60 * 60 * 24)))    // 24h
        completion(timeline)
    }
}

struct UntaggedDocumentsEntry: TimelineEntry {
    let date: Date
    let untaggedDocuments: Int
}

extension UntaggedDocumentsStatsView.Size {
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

struct UntaggedDocumentsWidget: Widget {
    @Environment(\.widgetFamily) var widgetFamily
    let kind: String = "UntaggedDocumentsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind,
                            provider: UntaggedDocumentsProvider()) { entry in
            UntaggedDocumentsStatsView(untaggedDocuments: entry.untaggedDocuments,
                                  size: .create(from: widgetFamily))
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Untagged Documents")
        .description("See how many documents are currently untagged or scan a new document.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview("Small", as: .systemSmall) {
    UntaggedDocumentsWidget()
} timeline: {
    UntaggedDocumentsEntry(date: .now, untaggedDocuments: 0)
    UntaggedDocumentsEntry(date: .now, untaggedDocuments: 5)
    UntaggedDocumentsEntry(date: .now, untaggedDocuments: 42)
}

#Preview("Middle", as: .systemMedium) {
    UntaggedDocumentsWidget()
} timeline: {
    UntaggedDocumentsEntry(date: .now, untaggedDocuments: 0)
    UntaggedDocumentsEntry(date: .now, untaggedDocuments: 5)
    UntaggedDocumentsEntry(date: .now, untaggedDocuments: 542)
}

#Preview("Large", as: .systemLarge) {
    UntaggedDocumentsWidget()
} timeline: {
    UntaggedDocumentsEntry(date: .now, untaggedDocuments: 0)
    UntaggedDocumentsEntry(date: .now, untaggedDocuments: 5)
    UntaggedDocumentsEntry(date: .now, untaggedDocuments: 42)
}
