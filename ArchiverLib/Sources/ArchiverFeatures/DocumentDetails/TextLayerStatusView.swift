//
//  TextLayerStatusView.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.02.26.
//

import PDFKit
import Shared
import SwiftUI

struct TextLayerStatusView: View {
    let documentURL: URL

    @State private var hasTextLayer: Bool?
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover = true
        } label: {
            if let hasTextLayer {
                Label(
                    hasTextLayer
                        ? String(localized: "Searchable", bundle: #bundle)
                        : String(localized: "Not searchable", bundle: #bundle),
                    systemImage: hasTextLayer
                        ? "checkmark.circle.fill"
                        : "xmark.circle.fill"
                )
                .foregroundStyle(hasTextLayer ? Color.green : Color.red)
            } else {
                ProgressView()
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover) {
            popoverContent
        }
        .task {
            hasTextLayer = checkTextLayer(url: documentURL)
        }
    }

    @ViewBuilder
    private var popoverContent: some View {
        if let hasTextLayer {
            VStack(alignment: .leading, spacing: 12) {
                if hasTextLayer {
                    Label(
                        String(localized: "Text layer present", bundle: #bundle),
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(Color.green)
                    .font(.headline)

                    Text("This PDF contains a text layer and is fully searchable.", bundle: #bundle)
                        .font(.body)
                } else {
                    Label(
                        String(localized: "No text layer", bundle: #bundle),
                        systemImage: "xmark.circle.fill"
                    )
                    .foregroundStyle(Color.red)
                    .font(.headline)

                    Text("This PDF contains no searchable text. OCR can add a text layer.", bundle: #bundle)
                        .font(.body)
                }

                HStack {
                    Spacer()
                    Button(String(localized: "OK", bundle: #bundle)) {
                        showPopover = false
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
            }
            .padding()
            .frame(minWidth: 260)
        }
    }

    private func checkTextLayer(url: URL) -> Bool {
        guard let pdf = PDFDocument(url: url) else { return false }
        return (0..<min(pdf.pageCount, 3)).contains {
            pdf.page(at: $0)?.string?.isEmpty == false
        }
    }
}
