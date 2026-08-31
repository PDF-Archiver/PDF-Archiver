//
//  PDFView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 31.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import PDFKit
import Shared
import SwiftUI

// Identifier for annotations added by this feature
private let dateHighlightAnnotationKey = "pa-date-highlight"

@MainActor
private func addDateHighlightAnnotations(to pdfView: PDFView, date: Date?) {
    guard let document = pdfView.document else { return }

    // Remove existing date highlight annotations
    for pageIndex in 0..<document.pageCount {
        guard let page = document.page(at: pageIndex) else { continue }
        for annotation in page.annotations where annotation.userName == dateHighlightAnnotationKey {
            page.removeAnnotation(annotation)
        }
    }

    guard let date else { return }

    let dateFormats = dateSearchStrings(for: date)
    var foundMatch = false

    for format in dateFormats {
        guard !foundMatch else { break }
        let selections = document.findString(format, withOptions: [])
        for selection in selections {
            for page in selection.pages {
                let bounds = selection.bounds(for: page)
                guard bounds.width > 0, bounds.height > 0 else { continue }
                // Highlight annotation
                let highlight = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                highlight.color = .yellow.withAlphaComponent(0.4)
                highlight.userName = dateHighlightAnnotationKey
                page.addAnnotation(highlight)

                // Border annotation
                let borderBounds = bounds.insetBy(dx: -2, dy: -2)
                let border = PDFAnnotation(bounds: borderBounds, forType: .square, withProperties: nil)
                border.color = .init(red: 0.8, green: 0.7, blue: 0.0, alpha: 0.7)
                let pdfBorder = PDFBorder()
                pdfBorder.lineWidth = 1
                border.border = pdfBorder
                border.interiorColor = nil
                border.userName = dateHighlightAnnotationKey
                page.addAnnotation(border)
                foundMatch = true
            }
        }
    }
}

private func dateSearchStrings(for date: Date) -> [String] {
    var results: [String] = []

    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    guard let year = components.year,
          let month = components.month,
          let day = components.day else { return [] }

    // swiftlint:disable identifier_name
    let dd = String(format: "%02d", day)
    let mm = String(format: "%02d", month)
    let yyyy = String(format: "%04d", year)
    // swiftlint:enable identifier_name

    // yyyy-MM-dd (ISO format, used by the app's naming convention)
    results.append("\(yyyy)-\(mm)-\(dd)")

    // dd.MM.yyyy (common German format)
    results.append("\(dd).\(mm).\(yyyy)")

    // dd/MM/yyyy
    results.append("\(dd)/\(mm)/\(yyyy)")

    // MM/dd/yyyy (US format)
    results.append("\(mm)/\(dd)/\(yyyy)")

    // Long format variants using DateFormatter for locale-aware month names
    for localeId in ["de_DE", "en_US"] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localeId)

        // "21. Februar 2026" / "February 21, 2026"
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        results.append(formatter.string(from: date))

        // "21. Feb. 2026" / "Feb 21, 2026"
        formatter.dateStyle = .medium
        results.append(formatter.string(from: date))
    }

    // Deduplicate while preserving order
    var seen = Set<String>()
    return results.filter { seen.insert($0).inserted }
}

#if os(macOS)
struct PDFCustomView: NSViewRepresentable {
    typealias NSViewType = PDFView

    private let pdfDocument: PDFDocument?
    private let highlightDate: Date?

    init(_ pdfDocument: PDFDocument?, highlightDate: Date? = nil) {
        self.pdfDocument = pdfDocument
        self.highlightDate = highlightDate
    }

    init(_ url: URL, highlightDate: Date? = nil) {
        self.pdfDocument = PDFDocument(url: url)
        self.highlightDate = highlightDate
    }

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.interpolationQuality = .low
        view.backgroundColor = .init(Color.paPDFBackgroundAsset)
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        guard let pdfDocument,
              view.document?.documentURL != pdfDocument.documentURL else {
            // Document unchanged, but highlight state may have changed
            addDateHighlightAnnotations(to: view, date: highlightDate)
            return
        }
        view.document = pdfDocument

        // 1. set displayMode (should always be singlePageContinuous, because this is the best way for the user to find details in the document) and enable auto scaling
        view.displayMode = .singlePageContinuous
        view.minScaleFactor = 0.1
        view.maxScaleFactor = 4.0
        view.autoScales = true

        #if DEBUG
        fitPageHeightForScreenshot(view, document: pdfDocument)
        #endif

        // 2. show the first page of the document
        view.goToFirstPage(self)

        // 3. highlight detected date if enabled
        addDateHighlightAnnotations(to: view, date: highlightDate)
    }

    #if DEBUG
    /// `autoScales` fits the width, which blows a receipt-shaped page up until only its head is
    /// visible. A screenshot fits the height instead, so the page keeps margins beside it.
    private func fitPageHeightForScreenshot(_ view: PDFView, document: PDFDocument) {
        guard ScreenshotScene.requested != nil,
              let page = document.page(at: 0) else { return }

        let pageHeight = page.bounds(for: .mediaBox).height
        // Deferred: the view has no bounds yet while SwiftUI is still updating it.
        DispatchQueue.main.async {
            guard view.bounds.height > 0 else { return }
            view.autoScales = false
            view.scaleFactor = view.bounds.height / pageHeight
        }
    }
    #endif
}
#else
struct PDFCustomView: UIViewRepresentable {
    typealias UIViewType = PDFView

    private let pdfDocument: PDFDocument?
    private let highlightDate: Date?

    init(_ pdfDocument: PDFDocument?, highlightDate: Date? = nil) {
        self.pdfDocument = pdfDocument
        self.highlightDate = highlightDate
    }

    init(_ url: URL, highlightDate: Date? = nil) {
        self.pdfDocument = PDFDocument(url: url)
        self.highlightDate = highlightDate
    }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.interpolationQuality = .low
        view.backgroundColor = .init(Color.paPDFBackgroundAsset)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        guard let pdfDocument,
              view.document?.documentURL != pdfDocument.documentURL else {
            // Document unchanged, but highlight state may have changed
            addDateHighlightAnnotations(to: view, date: highlightDate)
            return
        }
        view.document = pdfDocument

        // 1. set displayMode (should always be singlePageContinuous, because this is the best way for the user to find details in the document) and enable auto scaling
        view.displayMode = .singlePageContinuous
        view.minScaleFactor = 0.1
        view.maxScaleFactor = 4.0
        view.autoScales = true

        #if DEBUG
        fitPageHeightForScreenshot(view, document: pdfDocument)
        #endif

        // 2. show the first page of the document
        view.goToFirstPage(self)

        // 3. highlight detected date if enabled
        addDateHighlightAnnotations(to: view, date: highlightDate)
    }
}
#endif

#Preview {
    // swiftlint:disable:next force_unwrapping
    PDFCustomView(PDFDocument(url: Bundle.main.resourceURL!.appendingPathComponent("example-bill.pdf", conformingTo: .pdf)))
}
