//
//  PDFView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 31.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import PDFKit
import SwiftUI
import SwiftUIX

public struct PDFCustomView: AppKitOrUIKitViewRepresentable {
    public typealias AppKitOrUIKitViewType = PDFView

    private let pdfDocument: PDFDocument?

    public init(_ pdfDocument: PDFDocument?) {
        self.pdfDocument = pdfDocument
    }
    
    public init(_ url: URL) {
        self.pdfDocument = PDFDocument(url: url)
    }

    public func makeAppKitOrUIKitView(context: Context) -> PDFView {
        let view = PDFView()
        view.interpolationQuality = .low
        view.backgroundColor = .init(Color.paPDFBackground)
        return view
    }

    public func updateAppKitOrUIKitView(_ view: PDFView, context: Context) {
        guard let pdfDocument,
              view.document?.documentURL != pdfDocument.documentURL else { return }
        view.document = pdfDocument

        // 1. set displayMode (should always be singlePageContinuous, because this is the best way for the user to find details in the document) and enable auto scaling
        view.displayMode = .singlePageContinuous
        view.minScaleFactor = 0.1
        view.maxScaleFactor = 4.0
        view.autoScales = true

        // 2. show the first page of the document
        view.goToFirstPage(self)
    }
}

#if DEBUG
struct PDFCustomView_Previews: PreviewProvider {
    static var previews: some View {
        PDFCustomView(PDFDocument(url: Bundle.main.resourceURL!.appendingPathComponent("example-bill.pdf", conformingTo: .pdf)))
    }
}
#endif