//
//  DocumentView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 29.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI
import SwiftUIX

struct DocumentView: View {

    var viewModel: Document
    let showTagStatus: Bool
    let multilineTagList: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4.0) {
            HStack {
                if showTagStatus {
                    Text(viewModel.taggingStatus == .tagged ? "✅" : " ")
                }
                titleSubtitle
                    .layoutPriority(2)
                Spacer()
                if !showTagStatus && viewModel.downloadStatus.isRemote {
                    status
                        .fixedSize()
                        .layoutPriority(1)
                }
            }
            .layoutPriority(1)
            tags
                .layoutPriority(2)
            if !showTagStatus && viewModel.downloadStatus.isDownloading {
				ProgressView(value: viewModel.downloadStatus.percentageDownloading, total: 1.0)
					.progressViewStyle(.linear)
                    .foregroundColor(.paDarkGray)
                    .frame(maxHeight: 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 65.0)
    }

    var titleSubtitle: some View {
        VStack(alignment: .leading) {
            if viewModel.specification.isEmpty {
                Text("N/A")
                    .font(.body)
                    .foregroundColor(.gray)
            } else {
                Text(viewModel.specification.localizedCapitalized.replacingOccurrences(of: "-", with: " "))
                    .font(.body)
            }
            Text(viewModel.date ?? Date(), style: .date)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    var status: some View {
        VStack {
            Image(systemName: "icloud.and.arrow.down")
            Text(viewModel.size)
                .font(.caption)
        }
        .foregroundColor(.gray)
    }

    var tags: some View {
        TagListView(tags: .constant(viewModel.tags.sorted()), isEditable: false, isMultiLine: multilineTagList, tapHandler: nil)
            .font(.caption)
    }
}

// this is only needed, because a ViewBuilder could not be used with "if case ..." statements
fileprivate extension FileChange.DownloadStatus {
    var isDownloading: Bool {
        if case FileChange.DownloadStatus.downloading = self {
            return true
        } else {
            return false
        }
    }

    var isRemote: Bool {
        if case FileChange.DownloadStatus.remote = self {
            return true
        } else {
            return false
        }
    }

    var percentageDownloading: CGFloat {
        if case FileChange.DownloadStatus.downloading(let percent) = self {
            return CGFloat(percent)
        } else {
            return 0.0
        }
    }
}

#if DEBUG
struct DocumentView_Previews: PreviewProvider {
//    static let documentViewModel = DocumentViewModel(specification: "Ikea Bill",
//                                                     formattedDate: "30.10.2019",
//                                                     formattedSize: "1,2 MB",
//                                                     sortedTags: ["bill", "ikea"],
//                                                     downloadStatus: .downloading(percent: 0.123))
    static var previews: some View {
        let document = Document.create()
        DocumentView(viewModel: document, showTagStatus: false, multilineTagList: true)
            .preferredColorScheme(.light)
            .environment(\.sizeCategory, .extraExtraLarge)
            .previewLayout(.sizeThatFits)
            .frame(minWidth: 0.0, maxWidth: .infinity, minHeight: 0, maxHeight: 45.0)
            .padding()
    }
}
#endif
