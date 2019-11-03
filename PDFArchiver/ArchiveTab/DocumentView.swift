//
//  DocumentView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 29.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import SwiftUI

struct DocumentView: View {

    let viewModel: DocumentViewModel

    var body: some View {
        VStack(alignment: HorizontalAlignment.leading, spacing: 4.0) {
            HStack {
                titleSubtitle
                Spacer()
                if viewModel.downloadStatus < 1.0 {
                    status
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            tags
            if viewModel.downloadStatus > 0.0 && viewModel.downloadStatus < 1.0 {
                ProgressView(value: viewModel.downloadStatus)
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
        TagListView(tags: .constant(viewModel.sortedTags), isEditable: false, isMultiLine: false)
            .font(.caption)
    }
}

struct DocumentView_Previews: PreviewProvider {
    static let documentViewModel = DocumentViewModel(specification: "Ikea Bill",
                                                     formattedDate: "30.10.2019",
                                                     formattedSize: "1,2 MB",
                                                     sortedTags: ["bill", "ikea"],
                                                     downloadStatus: Float(0.33))
    static var previews: some View {
        DocumentView(viewModel: documentViewModel)
            .frame(minWidth: 0.0, maxWidth: .infinity, minHeight: 0, maxHeight: 45.0)
            .padding()
    }
}
