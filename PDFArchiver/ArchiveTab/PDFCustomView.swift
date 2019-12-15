//
//  PDFView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 31.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import PDFKit
import SwiftUI

struct PDFCustomView: UIViewRepresentable {

    private let pdfDocument: PDFDocument?

    init(_ pdfDocument: PDFDocument?) {
        self.pdfDocument = pdfDocument
    }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = .singlePageContinuous
        view.autoScales = true
        view.interpolationQuality = .low
        view.backgroundColor = .paPDFBackground
//        view.minScaleFactor = 0.1
//        view.maxScaleFactor = 4.0
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if let pdfDocument = pdfDocument {
            view.document = pdfDocument
            view.goToFirstPage(self)

//            // show the whole document in the view
//            view.scaleFactor = view.scaleFactorForSizeToFit
        }
    }
}

struct PDFCustomView_Previews: PreviewProvider {
    static var previews: some View {
        PDFCustomView(PDFDocument())
    }
}
