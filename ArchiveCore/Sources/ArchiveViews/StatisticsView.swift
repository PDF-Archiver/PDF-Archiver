//
//  SwiftUIView.swift
//  
//
//  Created by Julian Kahnert on 27.12.20.
//

import SwiftUI

struct StatisticsView: View {

    @Environment(\.horizontalSizeClass) private var sizeClass

    var viewModel: StatisticsViewModel

    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 12) {
                documentsView
                if !viewModel.topTags.isEmpty && sizeClass != .compact {
                    tagView
                }
                if !viewModel.topYears.isEmpty && sizeClass != .compact {
                    yearView
                }
            }

            if sizeClass == .compact && (!viewModel.topTags.isEmpty || !viewModel.topYears.isEmpty) {
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
            .font(.subheadline)
            HStack {
                Text("\(viewModel.untaggedDocumentCount)")
                    .foregroundColor(.gray)
                Text("untagged")
            }
            .font(.subheadline)
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
            .font(.subheadline)
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
            .font(.subheadline)
        }
        .padding()
    }
}

struct StatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        StatisticsView(viewModel: StatisticsViewModel.previewViewModel)
    }
}
