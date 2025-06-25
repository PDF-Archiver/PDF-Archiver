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

struct UntaggedDocumentsProviderT: TimelineProvider {
    func placeholder(in context: Context) -> UntaggedDocumentsEntryT {
        UntaggedDocumentsEntryT(date: Date(), untaggedDocuments: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (UntaggedDocumentsEntryT) -> Void) {
        let count = SharedDefaults.getUntaggedDocumentsCount()
        let entry = UntaggedDocumentsEntryT(date: Date(), untaggedDocuments: count)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<UntaggedDocumentsEntryT>) -> Void) {
        var entries: [UntaggedDocumentsEntryT] = []

        // we can only calculate the current state of the archive
        let count = SharedDefaults.getUntaggedDocumentsCount()
        let entry = UntaggedDocumentsEntryT(date: Date(), untaggedDocuments: count)
        entries.append(entry)

        let timeline = Timeline(entries: entries, policy: .after(Date().advanced(by: 60 * 60 * 24)))    // 24h
        completion(timeline)
    }
}

struct UntaggedDocumentsEntryT: TimelineEntry {
    let date: Date
    let untaggedDocuments: Int
}

struct WidgetUntaggedDocumentsEntryViewT: View {
    @Environment(\.widgetFamily) var widgetFamily

    var entry: UntaggedDocumentsProviderT.Entry

//    #warning("TODO: Hier muss noch einen Funktion rein, um direkt in die Tag-Ansicht zu springen. Vielleicht wäre es gut in die Ansicht der noch zu taggenden Dokumente zu springen sollte die Anzahl > 1 sein.")
    var actionButtons: some View {
         HStack {
            if entry.untaggedDocuments <= 0 {
                Link(destination: DeepLink.scan.url) {
                    Label("Scan", systemImage: "document.viewfinder")
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(
                            Capsule().fill(Color("paDarkRedAsset"))
                        )
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
            }
            
            
            if entry.untaggedDocuments > 0 {
                Link(destination: DeepLink.scan.url) {
                    Image(systemName: "doc.viewfinder")
                }
                .padding(10)
                .background(Circle().fill(Color.gray.opacity(0.3)))

            }
            
            if entry.untaggedDocuments > 0 {
                Link(destination: DeepLink.scan.url) {
                    Label("Tag", systemImage: "tag")
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(
                            Capsule().fill(Color("paDarkRedAsset"))
                        )
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
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
                        // Hintergrundsymbol
                        Image(systemName: "checkmark.seal.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundStyle(Color("paDarkRedAsset").opacity(0.4))
                            .padding([.top, .trailing], -40)
                        

                        // Textvordergrund
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
        case .systemMedium:
            VStack(alignment: .leading) {
                if entry.untaggedDocuments > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(entry.untaggedDocuments, format: .number)
                            .font(.system(size: 48, weight: .black))
//                            .font(/*@START_MENU_TOKEN@*/.largeTitle/*@END_MENU_TOKEN@*/)
//                            .fontWeight(.black)
                            

                        Image(systemName: "document.on.document")
                            .foregroundStyle(Color("paDarkRedAsset"))
                            .symbolRenderingMode(.hierarchical)
                            .font(.title)

                        Text("Untagged Documents")
                            .foregroundStyle(.secondary)
                            .font(.body)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ZStack(alignment: .topTrailing) {
                        // Hintergrundsymbol
                        Image(systemName: "checkmark.seal.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundStyle(Color("paDarkRedAsset").opacity(0.4))
                            .padding([.top, .trailing], -40)
                        

                        // Textvordergrund
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ZStack(alignment: .topTrailing) {
                        // Hintergrundsymbol
                        Image(systemName: "checkmark.seal.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundStyle(Color("paDarkRedAsset").opacity(0.4))
                            .padding([.top, .trailing], -40)
                        

                        // Textvordergrund
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct UntaggedDocumentsWidgetT: Widget {
    let kind: String = "UntaggedDocumentsWidgetT"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind,
                            provider: UntaggedDocumentsProviderT()) { entry in
            WidgetUntaggedDocumentsEntryViewT(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Untagged Documents by Tristan")
        .description("See how many documents are currently untagged or scan a new document.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview("Small", as: .systemSmall) {
    UntaggedDocumentsWidgetT()
} timeline: {
    UntaggedDocumentsEntryT(date: .now, untaggedDocuments: 0)
    UntaggedDocumentsEntryT(date: .now, untaggedDocuments: 5)
    UntaggedDocumentsEntryT(date: .now, untaggedDocuments: 42)
}

#Preview("Middle", as: .systemMedium) {
    UntaggedDocumentsWidgetT()
} timeline: {
    UntaggedDocumentsEntryT(date: .now, untaggedDocuments: 0)
    UntaggedDocumentsEntryT(date: .now, untaggedDocuments: 5)
    UntaggedDocumentsEntryT(date: .now, untaggedDocuments: 542)
}

#Preview("Large", as: .systemLarge) {
    UntaggedDocumentsWidgetT()
} timeline: {
    UntaggedDocumentsEntryT(date: .now, untaggedDocuments: 0)
    UntaggedDocumentsEntryT(date: .now, untaggedDocuments: 5)
    UntaggedDocumentsEntryT(date: .now, untaggedDocuments: 42)
}
