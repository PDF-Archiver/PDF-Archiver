//
//  ArchiveListItemView.swift
//  iOS
//
//  Created by Julian Kahnert on 19.03.24.
//

import SwiftUI
import OSLog

struct ArchiveListItemView: View {
    let documentSpecification: String
    let documentDate: Date
    let documentDownloadStatus: Double
    let documentTags: [String]
    let documentSize: Measurement<UnitInformationStorage>
    
    init(documentSpecification: String, documentDate: Date, documentDownloadStatus: Double, documentTags: [String], documentSize: Measurement<UnitInformationStorage>) {
        self.documentSpecification = documentSpecification
        self.documentDate = documentDate
        self.documentDownloadStatus = documentDownloadStatus
        self.documentTags = documentTags
        self.documentSize = documentSize
    }
    
    init(document: Document) {
        self.documentSpecification = document.specification
        self.documentDate = document.date
        self.documentDownloadStatus = document.downloadStatus
        self.documentTags = document.tags
        self.documentSize = document.size
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(documentSpecification)
                        .font(.headline)
                    Text(documentDate, format: .dateTime.year().month().day())
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
                Spacer()
                status(for: documentSize)
                    .opacity(documentDownloadStatus == 0 ? 1 : 0)
            }
            
            TagListView(tags: documentTags.sorted(), isEditable: false, isMultiLine: false, tapHandler: nil)
                .font(.caption)
            
            ProgressView(value: documentDownloadStatus, total: 1)
                .progressViewStyle(.linear)
                .foregroundColor(.paDarkGray)
                .frame(maxHeight: 4)
                .opacity((documentDownloadStatus == 0 || documentDownloadStatus == 1) ? 0 : 1)
        }
    }

    private func status(for documentSize: Measurement<UnitInformationStorage>) -> some View {
        VStack {
            Image(systemName: "icloud.and.arrow.down")
            Text(documentSize.converted(to: .bytes).formatted(.byteCount(style: .file)))
                .font(.caption)
        }
        .foregroundColor(.gray)
    }
}

#Preview {
    ArchiveListItemView(documentSpecification: "test-document",
                        documentDate: Date(),
                        documentDownloadStatus: 0.3,
                        documentTags: ["tag1", "tag2"],
                        documentSize: .init(value: 12345, unit: .kilobytes))
}
