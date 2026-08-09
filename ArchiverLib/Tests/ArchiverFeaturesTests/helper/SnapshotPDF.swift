//
//  SnapshotPDF.swift
//  ArchiverLib
//

import CoreGraphics
import Foundation

enum SnapshotPDFError: Error {
    case couldNotCreateContext
}

/// Writes a small one-page PDF so `PDFCustomView` has real content to show.
///
/// The page is drawn from plain rectangles rather than text - no font rendering means the reference
/// images cannot drift when system fonts change.
func makeSnapshotPDF(name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("pdf-archiver-snapshot-\(name).pdf")
    var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)

    guard let consumer = CGDataConsumer(url: url as CFURL),
          let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
        throw SnapshotPDFError.couldNotCreateContext
    }

    context.beginPDFPage(nil)

    context.setFillColor(gray: 1, alpha: 1)
    context.fill(mediaBox)

    // Headline
    context.setFillColor(gray: 0.2, alpha: 1)
    context.fill(CGRect(x: 60, y: 720, width: 280, height: 24))

    // Body copy
    context.setFillColor(gray: 0.75, alpha: 1)
    for index in 0..<20 {
        let isParagraphEnd = index % 5 == 4
        context.fill(CGRect(x: 60, y: 660 - CGFloat(index) * 30, width: isParagraphEnd ? 210 : 475, height: 11))
    }

    context.endPDFPage()
    context.closePDF()

    return url
}
