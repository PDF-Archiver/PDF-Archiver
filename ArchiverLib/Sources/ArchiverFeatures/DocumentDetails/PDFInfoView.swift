//
//  PDFInfoView.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.02.26.
//

import PDFKit
import Shared
import SwiftUI

struct PDFInfoView: View {
    let documentURL: URL

    @State private var pdfInfo: PDFInfo?
    @State private var showPopover = false

    private static func createPdfInfo(from url: URL) async -> PDFInfo {
        let pdf = PDFDocument(url: url)
        let meta = pdf?.documentAttributes

        var fileSize: String?
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attributes?[.size] as? Int {
            fileSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        } else {
            fileSize = nil
        }

        return PDFInfo(
            hasTextLayer: (0..<min(pdf?.pageCount ?? 0, 3)).contains {
                pdf?.page(at: $0)?.string?.isEmpty == false
            },
            pageCount: pdf?.pageCount ?? 0,
            fileSize: fileSize,
            creationDate: meta?[PDFDocumentAttribute.creationDateAttribute] as? Date,
            modificationDate: meta?[PDFDocumentAttribute.modificationDateAttribute] as? Date,
            title: (meta?[PDFDocumentAttribute.titleAttribute] as? String).flatMap { $0.isEmpty ? nil : $0 },
            author: (meta?[PDFDocumentAttribute.authorAttribute] as? String).flatMap { $0.isEmpty ? nil : $0 },
            subject: (meta?[PDFDocumentAttribute.subjectAttribute] as? String).flatMap { $0.isEmpty ? nil : $0 }
        )
    }

    var body: some View {
        Button {
            showPopover = true
        } label: {
            Label(
                pdfInfo?.hasTextLayer ?? true
                    ? String(localized: "Searchable", bundle: #bundle)
                    : String(localized: "Not searchable", bundle: #bundle),
                systemImage: "info"
            )
            .foregroundStyle(pdfInfo?.hasTextLayer ?? true ? Color.primary : Color.red)
        }
        .popover(isPresented: $showPopover) {
            if let info = pdfInfo {
                PopoverView(info: info)
            } else {
                ProgressView()
                    .padding()
            }
        }
        .task(id: documentURL) {
            pdfInfo = await Task.detached(priority: .userInitiated) {
                await Self.createPdfInfo(from: documentURL)
            }.value
        }
    }
}

extension PDFInfoView {
    fileprivate struct PDFInfo: Sendable {
        let hasTextLayer: Bool
        let pageCount: Int
        let fileSize: String?
        let creationDate: Date?
        let modificationDate: Date?
        let title: String?
        let author: String?
        let subject: String?
    }

    struct PopoverView: View {
        fileprivate let info: PDFInfo

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                infoRow(
                    label: String(localized: "OCR", bundle: #bundle),
                    systemImage: info.hasTextLayer ? "checkmark.circle.fill" : "xmark.circle.fill",
                    color: info.hasTextLayer ? .green : .red,
                    value: info.hasTextLayer
                        ? String(localized: "Available", bundle: #bundle)
                        : String(localized: "Not available", bundle: #bundle)
                )
                infoRow(
                    label: String(localized: "Pages", bundle: #bundle),
                    systemImage: "doc.text",
                    value: "\(info.pageCount)"
                )
                if let fileSize = info.fileSize {
                    infoRow(
                        label: String(localized: "File Size", bundle: #bundle),
                        systemImage: "internaldrive",
                        value: fileSize
                    )
                }

                if let title = info.title {
                    infoRow(
                        label: String(localized: "Title", bundle: #bundle),
                        systemImage: "textformat",
                        value: title
                    )
                }
                if let author = info.author {
                    infoRow(
                        label: String(localized: "Author", bundle: #bundle),
                        systemImage: "person",
                        value: author
                    )
                }
                if let subject = info.subject {
                    infoRow(
                        label: String(localized: "Subject", bundle: #bundle),
                        systemImage: "tag",
                        value: subject
                    )
                }

                if let date = info.creationDate {
                    infoRow(
                        label: String(localized: "Created", bundle: #bundle),
                        systemImage: "calendar",
                        value: date.formatted(date: .abbreviated, time: .shortened)
                    )
                }
                if let date = info.modificationDate {
                    infoRow(
                        label: String(localized: "Modified", bundle: #bundle),
                        systemImage: "calendar.badge.clock",
                        value: date.formatted(date: .abbreviated, time: .shortened)
                    )
                }

            }
            .frame(width: 250)
            .padding(8)
        }

        @ViewBuilder
        private func infoRow(label: String, systemImage: String, color: Color = .primary, value: String) -> some View {
            HStack {
                Label(label, systemImage: systemImage)
                    .foregroundStyle(color)
                Spacer()
                Text(value)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

#Preview("PDFInfoView - Toolbar") {
    NavigationStack {
        Text("Document")
            .toolbar {
                ToolbarItem {
                    PDFInfoView(documentURL: URL(fileURLWithPath: "/dev/null"))
                }
            }
    }
}

#Preview("PDFInfoView - Popover Content") {
    PDFInfoView.PopoverView(info: PDFInfoView.PDFInfo(
        hasTextLayer: true,
        pageCount: 12,
        fileSize: "2.4 MB",
        creationDate: Date(timeIntervalSince1970: 1_705_315_200),
        modificationDate: Date(timeIntervalSince1970: 1_740_009_600),
        title: "Annual Report 2024",
        author: "John Doe",
        subject: "Finance"
    ))
}
