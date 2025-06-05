//
//  UntaggedDocumentsWidget.swift
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

struct WidgetUntaggedDocumentsEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily

    var entry: UntaggedDocumentsProvider.Entry

    var body: some View {
        VStack {
            ZStack {
                VStack(spacing: 8) {
                    HStack(alignment: .bottom) {
                        Text(entry.untaggedDocuments, format: .number)
                            .fontWeight(.semibold)
                        Image(systemName: "document.on.document")
                            .foregroundStyle(Color.green)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .font(.title)

                    Text("Untagged Documents")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .opacity(entry.untaggedDocuments == 0 ? 0 : 1)

                VStack {
                    Image(systemName: "checkmark.seal")
                        .font(.title)
                        .foregroundStyle(Color.green)
                        .symbolRenderingMode(.hierarchical)

                    Text("All documents are tagged. 🎉")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .opacity(entry.untaggedDocuments == 0 ? 1 : 0)
            }

            HStack {
                Spacer()
                Link(destination: DeepLink.scan.url) {
                    Label("Scan", systemImage: "document.viewfinder")
                        .padding(10)
                        .background(ContainerRelativeShape().fill(Color.gray.opacity(0.3)))
                }
            }
            .padding(.top, 8)
        }
    }
}

struct UntaggedDocumentsWidget: Widget {
    let kind: String = "UntaggedDocumentsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind,
                            provider: UntaggedDocumentsProvider()) { entry in
            WidgetUntaggedDocumentsEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Untagged Documents")
        .description("Number of PDFs that are currently untagged.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    UntaggedDocumentsWidget()
} timeline: {
    UntaggedDocumentsEntry(date: .now, untaggedDocuments: 0)
    UntaggedDocumentsEntry(date: .now, untaggedDocuments: 5)
    UntaggedDocumentsEntry(date: .now, untaggedDocuments: 42)
}
