//
//  PDFProcessing.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 18.06.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import os.log
import PDFKit
import SwiftyTesseract
import UIKit
import Vision

class PDFProcessing: Operation {

    private let log = OSLog(subsystem: "DocumentProcessing", category: "DocumentProcessing")
    private let tesseract = SwiftyTesseract(languages: [.german, .english, .italian, .french, .swedish, .russian], bundle: .main, engineMode: .lstmOnly)

    private let confidenceThreshold = Float(0)
    private let images: [UIImage]
    private let documentSavePath: URL

    private var textBoxes = [CGRect]()

    init(_ images: [UIImage], documentSavePath: URL) {
        self.images = images
        self.documentSavePath = documentSavePath
    }

    override func main() {

        let textBoxRequests = setupTextBoxRequests()

        var textObservations = [TextObservation]()
        for image in images {
            if isCancelled {
                return
            }

            guard let cgImage = image.cgImage else { fatalError("Could not get the cgImage.") }
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            textBoxes = [CGRect]()

            // text rectangle recognition
            do {
                try requestHandler.perform(textBoxRequests)
            } catch {
                os_log("Failed to perform dectectTextBoxRequest with error: %@", log: log, type: .error, error.localizedDescription)
                assertionFailure("Failed to perform dectectTextBoxRequest with error: \(error.localizedDescription)")
            }

            // text recognition (OCR)
            var results = [TextObservationResult]()
            for textBox in textBoxes {
                guard let cgImage = cgImage.cropping(to: textBox) else { fatalError("Could not crop image.") }
                let croppedImage = UIImage(cgImage: cgImage)
                tesseract.performOCR(on: croppedImage) { text in
                    guard let text = text,
                        !text.isEmpty else { return }
                    results.append(TextObservationResult(rect: textBox, text: text))
                }
            }

            // append results
            textObservations.append(TextObservation(image: image, results: results))
        }

        // save the pdf
        let document = PDFProcessing.renderPdf(from: textObservations)
        document.write(to: documentSavePath)
    }

    // MARK: - Helper Functions

    private static func renderPdf(from observations: [TextObservation]) -> PDFDocument {
        let renderer = UIGraphicsPDFRenderer(bounds: .zero)
        let data = renderer.pdfData { context in
            for observation in observations {

                let bounds = CGRect(origin: .zero, size: observation.image.size)

                context.beginPage(withBounds: bounds, pageInfo: [:])
                observation.image.draw(in: bounds)
                for result in observation.results {
                    result.attributedText.draw(in: result.rect)
                }
            }
        }
        guard let document = PDFDocument(data: data) else { fatalError("Could not generate PDF document.") }
        return document
    }

    private func setupTextBoxRequests() -> [VNRequest] {
        let detectTextRectangleRequest = VNDetectTextRectanglesRequest { [weak self] (request, error) in

            guard error == nil else { fatalError("VNDetectTextRectanglesRequest errored:\n\(error?.localizedDescription ?? "")") }
            guard let self = self else { return }
            guard let observations = request.results as? [VNTextObservation] else {
                assertionFailure("The observations are of an unexpected type.")
                return
            }

            for observation in observations where observation.confidence > self.confidenceThreshold {
                self.textBoxes.append(observation.boundingBox)
            }
        }
        return [detectTextRectangleRequest]
    }

    // MARK: - Helper Types

    private struct TextObservationResult {
        let rect: CGRect
        let text: String
        var attributedText: NSAttributedString {
            return NSAttributedString.createCleared(from: text, with: rect.size)
        }
    }

    private struct TextObservation {
        let image: UIImage
        let results: [TextObservationResult]
    }

}

extension UIFont {
    convenience init?(named fontName: String, fitting text: String, into targetSize: CGSize, with attributes: [NSAttributedString.Key: Any], options: NSStringDrawingOptions) {
        var attributes = attributes
        let fontSize = targetSize.height

        attributes[.font] = UIFont(name: fontName, size: fontSize)
        let size = text.boundingRect(with: CGSize(width: .greatestFiniteMagnitude, height: fontSize),
                                     options: options,
                                     attributes: attributes,
                                     context: nil).size

        let heightSize = targetSize.height / (size.height / fontSize)
        let widthSize = targetSize.width / (size.width / fontSize)

        self.init(name: fontName, size: min(heightSize, widthSize))
    }
}

extension NSAttributedString {
    static func createCleared(from text: String, with size: CGSize) -> NSAttributedString {

        let fontName = UIFont.systemFont(ofSize: 0).fontName
        var attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.foregroundColor: UIColor.red]
        attributes[.font] = UIFont(named: fontName, fitting: text, into: size, with: attributes, options: .usesFontLeading)

        return NSAttributedString(string: text, attributes: attributes)
    }
}
