//
//  PDFProcessing.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 18.06.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import os.log
import PDFKit
import SwiftyTesseract
import UIKit
import Vision

class PDFProcessing: Operation {

    typealias ProgressHandler = ((Float) -> Void)

    private let log = OSLog(subsystem: "DocumentProcessing", category: "DocumentProcessing")
    private let tesseract = SwiftyTesseract(languages: [.german, .english, .italian, .french, .swedish, .russian], bundle: .main, engineMode: .lstmOnly)

    private let mode: Mode
    private let progressHandler: ProgressHandler?
    private let confidenceThreshold = Float(0)

    private var detectTextRectangleObservations = [VNTextObservation]()

    var documentId: UUID? {
        if case Mode.images(let documentId) = mode {
            return documentId
        } else {
            return nil
        }
    }

    init(of mode: Mode, progressHandler: ProgressHandler?) {
        self.mode = mode
        self.progressHandler = progressHandler
    }

    override func main() {

        if isCancelled {
            return
        }
        guard let untaggedPath = StorageHelper.Paths.untaggedPath else { fatalError("Could not find untagged documents path.") }

        // signal the start of the operation
        let start = Date()
        Log.info("Process a document.")
        progressHandler?(Float(0))

        let path: URL
        switch mode {
        case .images(let documentId):

            // apply OCR and create a PDF
            path = createPdf(of: documentId)
        case .pdf(let inputPath):

            // just use the input PDF
            path = inputPath
        }

        if isCancelled {
            return
        }

        guard let document = PDFDocument(url: path) else {
            assertAndLog("Could not find a valid PDF in url.")
            return
        }

        // generate filename by analysing the image
        let filename = PDFProcessing.getFilename(from: document)
        let filepath = untaggedPath.appendingPathComponent(filename)

        do {
            try FileManager.default.createFolderIfNotExists(filepath.deletingLastPathComponent())
            try FileManager.default.moveItem(at: path, to: filepath)
        } catch let error {
            assertAndLog("Could not move pdf file.", extra: ["error": error.localizedDescription])
        }

        // log the processing time
        let timeDiff = Date().timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate
        Log.info("Processing completed", extra: ["processing_time": timeDiff])
        progressHandler?(Float(1))
    }

    // MARK: - Helper Functions

    private static func getFilename(from document: PDFDocument) -> String {
        os_log("Creating filename", log: ImageConverter.log, type: .debug)

        // get default specification
        let specification = Constants.documentDescriptionPlaceholder + Date().timeIntervalSince1970.description

        // get OCR content
        var content = ""
        for pageNumber in 0..<min(document.pageCount, 3) {
            content += document.page(at: pageNumber)?.string ?? ""
        }

        // use the default filename if no content could be found
        guard !content.isEmpty else {
            return Document.createFilename(date: Date(), specification: specification, tags: Set([Constants.documentTagPlaceholder]))
        }

        // parse the date
        let parsedDate = DateParser.parse(content)?.date ?? Date()

        // parse the tags
        var newTags = TagParser.parse(content)
        if newTags.isEmpty {
            newTags.insert(Constants.documentTagPlaceholder)
        } else {

            // only use tags that are already in the archive
            let archiveTags = DocumentService.archive.getAvailableTags(with: []).map { $0.name }
            newTags = Set(newTags.intersection(Set(archiveTags)).prefix(5))
        }

        return Document.createFilename(date: parsedDate, specification: specification, tags: newTags)
    }

    private func createPdf(of documentId: UUID) -> URL {
        // initial setup
        let textBoxRequests = setupTextBoxRequests()
        guard let tempImagePath = StorageHelper.Paths.tempImagePath else { fatalError("Could not find temp image path.") }
        do {
            // check if the parent folder exists
            try FileManager.default.createFolderIfNotExists(tempImagePath)
        } catch {
            fatalError("Could not create unttaged documents folder.")
        }

        let contentPaths = (try? FileManager.default.contentsOfDirectory(at: tempImagePath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])) ?? []
        let imageUrls = contentPaths.filter { $0.lastPathComponent.starts(with: documentId.uuidString) }

        var textObservations = [TextObservation]()
        for (imageIndex, imageUrl) in imageUrls.enumerated() {

            guard let image = UIImage(contentsOfFile: imageUrl.path) else {
                fatalError("Could not find image at \(imageUrl.path)")
            }

            guard let cgImage = image.cgImage else { fatalError("Could not get the cgImage.") }
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            detectTextRectangleObservations = [VNTextObservation]()

            // text rectangle recognition
            do {
                try requestHandler.perform(textBoxRequests)
            } catch {
                assertAndLog("Failed to perform dectectTextBoxRequest.", extra: ["error": error.localizedDescription])
            }

            // text recognition (OCR)
            var results = [TextObservationResult]()
            for (observationIndex, observation) in detectTextRectangleObservations.enumerated() {

                // build and start processing of one observation
                let textBox = self.transform(observation: observation, in: image)
                if let croppedImage = image.crop(rectangle: textBox) {
                    self.tesseract.performOCR(on: croppedImage) { text in
                        guard let text = text,
                            !text.isEmpty else { return }
                        results.append(TextObservationResult(rect: textBox, text: text))
                    }
                }

                // update the progress view
                let progress = Float(Float(imageIndex) + Float(observationIndex) / Float(detectTextRectangleObservations.count)) / Float(imageUrls.count)
                let borderedProgress = min(max(progress, 0), 1)
                progressHandler?(borderedProgress)
            }

            // append results
            textObservations.append(TextObservation(image: image, results: results))
        }

        // save the pdf
        let document = PDFProcessing.renderPdf(from: textObservations)

        // save document
        let tempfilepath = tempImagePath.appendingPathComponent(documentId.uuidString).appendingPathExtension("pdf")
        document.write(to: tempfilepath)

        // delete original images
        for imageUrl in imageUrls {
            try? FileManager.default.removeItem(at: imageUrl)
        }

        return tempfilepath
    }

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

    private func assertAndLog(_ message: String, extra: [String: Any] = [:]) {
        Log.error(message, extra: extra)
        assertionFailure(message)
    }

    // MARK: - Helper Types

    enum Mode {
        case pdf(URL)
        case images(UUID)
    }

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
