//
//  SwiftUIView.swift
//  
//
//  Created by Julian Kahnert on 27.12.20.
//

import SwiftData
import SwiftUI

struct StatisticsView: View {
    private static let bodyFont: Font = .subheadline
    @Environment(\.horizontalSizeClass) private var sizeClass

    @Query private var documents: [Document]

    @State private var viewModel = StatisticsViewModel()

    var body: some View {
        let isCompact = sizeClass == .compact
        VStack {
            HStack(alignment: .top, spacing: 12) {
                documentsView
                if !viewModel.topTags.isEmpty && !isCompact {
                    tagView
                }
                if !viewModel.topYears.isEmpty && !isCompact {
                    yearView
                }
            }

            if isCompact && (!viewModel.topTags.isEmpty || !viewModel.topYears.isEmpty) {
                HStack(alignment: .top, spacing: 12) {
                    if !viewModel.topTags.isEmpty {
                        tagView
                    }
                    if !viewModel.topYears.isEmpty {
                        yearView
                    }
                }
            }
        }
        .redacted(reason: viewModel.isLoading ? .placeholder : [])
        // Currently MVVM is difficult with SwiftData when you want to listen to changes in documets.
        // So we have built this workaround to only run updateData when the view gets initialized the first time or when some changes happen.
        // It will not be triggered again, when navigating back and forth in the SettingsView.
        .task {
            guard !viewModel.isInitialized else { return }
            viewModel.updateData(with: documents)
        }
        .onChange(of: documents, initial: false) { _, newValue in
            viewModel.updateData(with: newValue)
        }
    }

    private var documentsView: some View {
        VStack(alignment: .leading) {
            Label("Documents", systemImage: "doc.text")
                .font(.headline)
                .padding(.bottom, 4)
            HStack {
                Text("\(viewModel.taggedDocumentCount)")
                    .foregroundColor(.gray)
                Text("tagged")
            }
            .font(Self.bodyFont)
            HStack {
                Text("\(viewModel.untaggedDocumentCount)")
                    .foregroundColor(.gray)
                Text("untagged")
            }
            .font(Self.bodyFont)
        }
        .padding()
    }

    private var tagView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Top Tags", systemImage: "tag")
                .font(.headline)
                .padding(.bottom, 4)
            ForEach(viewModel.topTags, id: \.0) { (tag, count) in
                HStack {
                    Text("\(count)")
                        .foregroundColor(.gray)
                    Text(tag.localizedCapitalized)
                        .lineLimit(1)
                        .minimumScaleFactor(0.95)
                }
            }
            .font(Self.bodyFont)
        }
        .padding()
    }

    private var yearView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Top Years", systemImage: "calendar")
                .font(.headline)
                .padding(.bottom, 4)
            ForEach(viewModel.topYears, id: \.0) { (year, count) in
                HStack {
                    Text("\(count)")
                        .foregroundColor(.gray)
                    Text(year)
                        .lineLimit(1)
                        .minimumScaleFactor(0.95)
                }
            }
            .font(Self.bodyFont)
        }
        .padding()
    }
}

#Preview {
    StatisticsView()
}
