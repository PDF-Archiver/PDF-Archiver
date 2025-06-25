//
//  NewFeatureWidget.swift
//  PDFArchiver
//
//  Created by Tristan Germer on 22.06.25.
//

import WidgetKit
import SwiftUI

struct NewFeatureEntry: TimelineEntry {
    let date: Date
}



struct NewFeatureProvider: TimelineProvider {
    func placeholder(in context: Context) -> NewFeatureEntry {
        NewFeatureEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (NewFeatureEntry) -> ()) {
        completion(NewFeatureEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NewFeatureEntry>) -> ()) {
        let entry = NewFeatureEntry(date: Date())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct NewFeatureWidgetEntryView: View {
    var entry: NewFeatureProvider.Entry

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Neues Widget")
                Spacer()
                Text("🎉")
            }
            Spacer()
        }
        .containerBackground(Color("paDarkRedAsset"), for: .widget)
    }
}

struct NewFeatureWidget: Widget {
    let kind: String = "NewFeatureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NewFeatureProvider()) { entry in
            NewFeatureWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Neues Feature")
        .description("Dies ist ein neues Widget.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}


#Preview("Small", as: .systemSmall) {
    NewFeatureWidget()
} timeline: {
    NewFeatureEntry(date: .now)
}

#Preview("Middle", as: .systemMedium) {
    NewFeatureWidget()
} timeline: {
    NewFeatureEntry(date: .now)
}
