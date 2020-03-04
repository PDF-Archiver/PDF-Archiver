//
//  DocumentView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 29.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import SwiftUI
import SwiftUIX

struct DocumentView: View {

    let viewModel: DocumentViewModel
    let showTagStatus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4.0) {
            HStack {
                if showTagStatus {
                    Text(viewModel.taggingStatus == .tagged ? "✅" : " ")
                }
                titleSubtitle
                Spacer()
                if !showTagStatus && !viewModel.downloadStatus.isLocal {
                    status
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            tags
            if !showTagStatus && viewModel.downloadStatus.isDownloading {
                LinearProgressBar(viewModel.downloadStatus.percentageDownloading)
                    .foregroundColor(Color(.paDarkGray))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 65.0)
    }

    var titleSubtitle: some View {
        VStack(alignment: .leading) {
            Text(viewModel.specification)
                .font(.body)
            Text(viewModel.formattedDate)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    var status: some View {
        VStack {
            Image(systemName: "icloud.and.arrow.down")
            Text(viewModel.formattedSize)
                .font(.caption)
        }
        .foregroundColor(.gray)
    }

    var tags: some View {
        TagListView(tags: .constant(viewModel.sortedTags), isEditable: false, isMultiLine: false, tapHandler: nil)
            .font(.caption)
    }
}

// this is only needed, because a ViewBuilder could not be used with "if case ..." statements
fileprivate extension DownloadStatus {
    var isDownloading: Bool {
        if case DownloadStatus.downloading(_) = self {
            return true
        } else {
            return false
        }
    }

    var isLocal: Bool {
        if case DownloadStatus.local = self {
            return true
        } else {
            return false
        }
    }

    var percentageDownloading: CGFloat {
        if case DownloadStatus.downloading(let percentDownloaded) = self {
            return CGFloat(percentDownloaded)
        } else {
            return 0.0
        }
    }
}

#if DEBUG
struct DocumentView_Previews: PreviewProvider {
    static let documentViewModel = DocumentViewModel(specification: "Ikea Bill",
                                                     formattedDate: "30.10.2019",
                                                     formattedSize: "1,2 MB",
                                                     sortedTags: ["bill", "ikea"],
                                                     downloadStatus: .downloading(percentDownloaded: 0.33))
    static var previews: some View {
        DocumentView(viewModel: documentViewModel, showTagStatus: false)
            .frame(minWidth: 0.0, maxWidth: .infinity, minHeight: 0, maxHeight: 45.0)
            .padding()
    }
}
#endif
