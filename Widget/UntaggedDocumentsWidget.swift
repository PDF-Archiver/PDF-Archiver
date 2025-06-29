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

    var actionButtons: some View {
         HStack {
            if entry.untaggedDocuments <= 0 {
                
                if #available(iOS 26.0, *) {
                    Link(destination: DeepLink.scan.url) {
                        Label("Scan", systemImage: "document.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .tint(Color("paDarkRedAsset"))
                } else {
                    Link(destination: DeepLink.scan.url) {
                        Label("Scan", systemImage: "document.viewfinder")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(
                        Capsule().fill(Color("paDarkRedAsset"))
                    )
                    .foregroundColor(.white)
                }
                

                
            } else {
                if #available(iOS 26.0, *) {
                    Link(destination: DeepLink.scan.url) {
                        Image(systemName: "doc.viewfinder")
                    }
                    .buttonStyle(.glass)
                    .tint(Color(.gray))

                    Link(destination: DeepLink.tag.url) {
                        Label("Tag", systemImage: "tag")
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .tint(Color("paDarkRedAsset"))
                } else {
                    Link(destination: DeepLink.scan.url) {
                        Image(systemName: "doc.viewfinder")
                    }
                    .padding(10)
                    .background(Circle().fill(Color.gray.opacity(0.3)))

                    Link(destination: DeepLink.tag.url) {
                        Label("Tag", systemImage: "tag")
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(10)
                    .background(
                        Capsule().fill(Color("paDarkRedAsset"))
                    )
                    .foregroundColor(.white)
                }
                
            }
         }
        .padding(.top, 8)
    }

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            VStack(alignment: .leading) {
                if entry.untaggedDocuments > 0 {
                    VStack(spacing: 8) {
                        HStack(alignment: .bottom, spacing: 8) {
                            Text(entry.untaggedDocuments, format: .number)
                                .fontWeight(.black)
                                .foregroundStyle(Color(.black))

                            Image(systemName: "document.on.document")
                                .foregroundStyle(Color("paDarkRedAsset"))
                                .symbolRenderingMode(.hierarchical)
                        }
                        .font(.largeTitle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Untagged Documents")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "checkmark.seal.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundStyle(Color("paDarkRedAsset").opacity(0.4))
                            .padding([.top, .trailing], -40)

                        Text("All documents are tagged. 🎉")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 40)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()

                actionButtons
            }

        case .systemMedium:
            VStack(alignment: .leading) {
                if entry.untaggedDocuments > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(entry.untaggedDocuments, format: .number)
                            .font(.system(size: 48, weight: .black))

                        Image(systemName: "document.on.document")
                            .foregroundStyle(Color("paDarkRedAsset"))
                            .symbolRenderingMode(.hierarchical)
                            .font(.title)

                        Text("Untagged Documents")
                            .foregroundStyle(.secondary)
                            .font(.body)
                            .lineLimit(1)
                            .minimumScaleFactor(0.2)

                        Spacer()
                    }
                } else {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "checkmark.seal.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundStyle(Color("paDarkRedAsset").opacity(0.4))
                            .padding([.top, .trailing], -40)

                        Text("All documents are tagged. 🎉")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 40)
                    }
                }

                Spacer()

                actionButtons
            }
        default:
            VStack(alignment: .leading) {
                if entry.untaggedDocuments > 0 {
                    VStack(spacing: 8) {
                        HStack(alignment: .bottom, spacing: 8) {
                            Text(entry.untaggedDocuments, format: .number)
                                .fontWeight(.black)

                            Image(systemName: "document.on.document")
                                .foregroundStyle(Color("paDarkRedAsset"))
                                .symbolRenderingMode(.hierarchical)
                        }
                        .font(.largeTitle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Untagged Documents")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "checkmark.seal.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundStyle(Color("paDarkRedAsset").opacity(0.4))
                            .padding([.top, .trailing], -40)

                        Text("All documents are tagged. 🎉")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 40)
                    }
                }

                Spacer()

                actionButtons
            }
        }
    }
}

struct UntaggedDocumentsWidget: Widget {
    let kind: String = "UntaggedDocumentsWidgetT"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind,
                            provider: UntaggedDocumentsProvider()) { entry in
            WidgetUntaggedDocumentsEntryView(entry: entry)
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
