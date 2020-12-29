//
//  SwiftUIView.swift
//  
//
//  Created by Julian Kahnert on 27.12.20.
//

import SwiftUI

struct StatisticsView: View {

    #if os(macOS)
    private static let bodyFont: Font = .body
    #else
    private static let bodyFont: Font = .subheadline
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    let viewModel: StatisticsViewModel

    var body: some View {
        #if os(macOS)
        let isCompact = false
        #else
        let isCompact = sizeClass == .compact
        #endif
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

struct StatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        StatisticsView(viewModel: StatisticsViewModel.previewViewModel)
    }
}
