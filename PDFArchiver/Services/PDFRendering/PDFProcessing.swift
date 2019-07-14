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

    typealias ProgressHandler = ((Float) -> Void)

    private let log = OSLog(subsystem: "DocumentProcessing", category: "DocumentProcessing")
    private let tesseract = SwiftyTesseract(languages: [.german, .english, .italian, .french, .swedish, .russian], bundle: .main, engineMode: .lstmOnly)

    private let confidenceThreshold = Float(0)
    private let images: [UIImage]
    private let progressHandler: ProgressHandler?
    private let documentSavePath: URL
    private let ocrProcessingQueue = DispatchQueue.global(qos: .userInitiated)
    private let ocrProcessingTimeout = 60   // in seconds

    private var detectTextRectangleObservations = [VNTextObservation]()

    init(_ images: [UIImage], documentSavePath: URL, progressHandler: ProgressHandler?) {
        self.images = images
        self.documentSavePath = documentSavePath
        self.progressHandler = progressHandler
    }

    override func main() {

        // signal the start of the operation
        progressHandler?(Float(0))

        let textBoxRequests = setupTextBoxRequests()

        var textObservations = [TextObservation]()
        for (imageIndex, image) in images.enumerated() {
            if isCancelled {
                return
            }

            guard let cgImage = image.cgImage else { fatalError("Could not get the cgImage.") }
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            detectTextRectangleObservations = [VNTextObservation]()

            // text rectangle recognition
            do {
                try requestHandler.perform(textBoxRequests)
            } catch {
                os_log("Failed to perform dectectTextBoxRequest with error: %@", log: log, type: .error, error.localizedDescription)
                assertionFailure("Failed to perform dectectTextBoxRequest with error: \(error.localizedDescription)")
            }

            // text recognition (OCR)
            var results = [TextObservationResult]()
            for (observationIndex, observation) in detectTextRectangleObservations.enumerated() {

                // build and start processing of one observation
                let semaphore = DispatchSemaphore(value: 0)
                let item = DispatchWorkItem {
                    let textBox = self.transform(observation: observation, in: image)
                    if let croppedImage = image.crop(rectangle: textBox) {
                        self.tesseract.performOCR(on: croppedImage) { text in
                            guard let text = text,
                                !text.isEmpty else { return }
                            results.append(TextObservationResult(rect: textBox, text: text))
                        }
                    }
                    semaphore.signal()
                }
                ocrProcessingQueue.async(execute: item)

                // cancel operation if it timed out
                let result = semaphore.wait(wallTimeout: .now() + .seconds(ocrProcessingTimeout))
                if result == .timedOut {
                    item.cancel()
                }

                // update the progress view
                let progress = Float(Float(imageIndex) + Float(observationIndex) / Float(detectTextRectangleObservations.count)) / Float(images.count)
                let borderedProgress = min(max(progress, 0), 1)
                progressHandler?(borderedProgress)
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
                self.detectTextRectangleObservations.append(observation)
            }
        }
        return [detectTextRectangleRequest]
    }

    private func transform(observation: VNTextObservation, in image: UIImage) -> CGRect {

        // special thanks to: https://github.com/g-r-a-n-t/serial-vision/
        var transform = CGAffineTransform.identity
        transform = transform.scaledBy(x: image.size.width, y: -image.size.height)
        transform = transform.translatedBy(x: 0, y: -1 )

        return CGRect(x: observation.boundingBox.applying(transform).origin.x,
                      y: observation.boundingBox.applying(transform).origin.y,
                      width: observation.boundingBox.applying(transform).width,
                      height: observation.boundingBox.applying(transform).height)
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
    fileprivate convenience init?(named fontName: String, fitting text: String, into targetSize: CGSize, with attributes: [NSAttributedString.Key: Any], options: NSStringDrawingOptions) {
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
    fileprivate static func createCleared(from text: String, with size: CGSize) -> NSAttributedString {

        let fontName = UIFont.systemFont(ofSize: 0).fontName
        var attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.foregroundColor: UIColor.clear]
        attributes[.font] = UIFont(named: fontName, fitting: text, into: size, with: attributes, options: .usesFontLeading)

        return NSAttributedString(string: text, attributes: attributes)
    }
}
