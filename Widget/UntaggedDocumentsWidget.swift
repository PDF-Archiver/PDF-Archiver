//
//  UntaggedDocumentsWidget.swift
//  Widget
//
//  Created by Julian Kahnert on 29.05.25.
//

import AppIntents
import ArchiverIntents
import Shared
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

private struct UntaggedDocumentsEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: UntaggedDocumentsEntry

    var body: some View {
        UntaggedDocumentsStatsView(untaggedDocuments: entry.untaggedDocuments,
                                   size: widgetFamily == .systemMedium ? .medium : .small)
            .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct UntaggedDocumentsWidget: Widget {
    let kind: String = "UntaggedDocumentsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind,
                            provider: UntaggedDocumentsProvider()) { entry in
            UntaggedDocumentsEntryView(entry: entry)
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
