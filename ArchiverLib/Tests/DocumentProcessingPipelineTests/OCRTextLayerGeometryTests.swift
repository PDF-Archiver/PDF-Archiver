//
//  OCRTextLayerGeometryTests.swift
//  ArchiverLib
//

import ArchiverModels
import Foundation
import PDFKit
import Testing

@testable import DocumentProcessingPipeline

/// Guards the coordinate space of the invisible OCR text layer.
///
/// `PDFOCREngine` maps normalized Vision coordinates into a y-down image space
/// and then into page space. A flipped origin or a wrong scale stays invisible
/// in the other tests - the text layer is there, `hasTextLayer` is true and the
/// page count matches - but text selection and search would land in the wrong
/// place. This test compares *where* the text ends up against the real text
/// layer of the same document.
struct OCRTextLayerGeometryTests {

    /// Words of `page`, grouped into horizontal bands of the page height.
    private func wordsPerBand(_ page: PDFPage, bands: Int) -> [Set<String>] {
        let bounds = page.bounds(for: .mediaBox)
        return (0..<bands).map { index in
            let bandRect = CGRect(x: bounds.minX,
                                  y: bounds.minY + bounds.height * CGFloat(index) / CGFloat(bands),
                                  width: bounds.width,
                                  height: bounds.height / CGFloat(bands))
            let text = page.selection(for: bandRect)?.string ?? ""
            return Set(text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 4 })
        }
    }

    @Test(.tags(.ocr))
    func ocrTextLandsInTheSameBandAsTheOriginal() async throws {
        let bands = 4

        // Reference: the original PDF and its real text layer.
        let sourcePdf = try #require(PDFDocument(url: Bundle.billPDFUrl))
        let sourcePage = try #require(sourcePdf.page(at: 0))
        let referenceBands = wordsPerBand(sourcePage, bands: bands)

        // Subject: the same page rasterized, then OCR'd back into a text layer.
        let bounds = sourcePage.bounds(for: .mediaBox)
        let image = sourcePage.thumbnail(of: CGSize(width: bounds.width * 3, height: bounds.height * 3),
                                        for: .mediaBox)
        let pdf = PDFMetadataTests.createImageOnlyPDF(from: image)
        try await PDFOCREngine.addTextLayer(to: pdf, quality: .lossless)
        let ocrBands = wordsPerBand(try #require(pdf.page(at: 0)), bands: bands)

        let referenceCount = referenceBands.reduce(0) { $0 + $1.count }
        let sameBandCount = zip(referenceBands, ocrBands).reduce(0) { $0 + $1.0.intersection($1.1).count }
        try #require(referenceCount > 0)

        // Words the OCR missed entirely count against this ratio too, so the
        // threshold stays well below the ~86% observed on real hardware.
        // A flipped or mis-scaled layer scatters words and drops far lower.
        let sameBandRatio = Double(sameBandCount) / Double(referenceCount)
        #expect(sameBandRatio > 0.6,
                "only \(sameBandCount)/\(referenceCount) words landed in their original band - text layer misaligned")
    }
}
