//
//  PDFProcessing.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 18.06.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable cyclomatic_complexity function_body_length

import ArchiveLib
import os.log
import PDFKit
import UIKit
import Vision

enum PDFProcessingError: Error {
    case unttaggedDocumentsPathNotFound
    case pdfNotFound
}

class PDFProcessing: Operation {

    typealias ProgressHandler = ((Float) -> Void)

    private let log = OSLog(subsystem: "DocumentProcessing", category: "DocumentProcessing")

    private let mode: Mode
    private let progressHandler: ProgressHandler?
    private let confidenceThreshold = Float(0)

    private(set) var error: Error?
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

        do {
            if isCancelled {
                return
            }
            guard let untaggedPath = StorageHelper.Paths.untaggedPath else { throw PDFProcessingError.unttaggedDocumentsPathNotFound }
            try FileManager.default.createFolderIfNotExists(untaggedPath)

            // signal the start of the operation
            let start = Date()
            Log.send(.info, "Process a document.")
            progressHandler?(Float(0))

            let path: URL
            switch mode {
            case .images(let documentId):

                // apply OCR and create a PDF
                try path = createPdf(of: documentId)
            case .pdf(let inputPath):

                // just use the input PDF
                path = inputPath
            }

            if isCancelled {
                return
            }

            guard let document = PDFDocument(url: path) else { throw PDFProcessingError.pdfNotFound }

            // generate filename by analysing the image
            let filename = PDFProcessing.getFilename(from: document)
            let filepath = untaggedPath.appendingPathComponent(filename)

            try FileManager.default.moveItem(at: path, to: filepath)

            // log the processing time
            let timeDiff = Date().timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate
            Log.send(.info, "Processing completed", extra: ["processing_time": String(timeDiff)])
            progressHandler?(Float(1))
        } catch let error {
            self.error = error
        }
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
            let archiveTags = DocumentService.archive.getAvailableTags(with: [])
            newTags = Set(newTags.intersection(Set(archiveTags)).prefix(5))
        }

        return Document.createFilename(date: parsedDate, specification: specification, tags: newTags)
    }

    private func createPdf(of documentId: UUID) throws -> URL {
        // initial setup
        guard let tempImagePath = StorageHelper.Paths.tempImagePath else { fatalError("Could not find temp image path.") }

        // check if the parent folder exists
        try FileManager.default.createFolderIfNotExists(tempImagePath)

        // STEP I: get all image urls
        let allImageUrls = (try? FileManager.default.contentsOfDirectory(at: tempImagePath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])) ?? []

        // STEP II: filter and sort those urls in a second step to avoid shuffeling around pages
        let sortedDocumentUrls = allImageUrls
            .filter { $0.lastPathComponent.starts(with: documentId.uuidString) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var textObservations = [TextObservation]()
        for (imageIndex, imageUrl) in sortedDocumentUrls.enumerated() {

            guard let image = UIImage(contentsOfFile: imageUrl.path) else {
                fatalError("Could not find image at \(imageUrl.path)")
            }

            guard let cgImage = image.cgImage else { fatalError("Could not get the cgImage.") }
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            var detectTextRectangleObservations = [VNTextObservation]()
            let textBoxRequests = VNDetectTextRectanglesRequest { (request, error) in

                if let error = error {
                    Log.send(.error, "Error in text recognition.", extra: ["error": error.localizedDescription])
                    return
                }

                for observation in (request.results as? [VNTextObservation] ?? []) where observation.confidence > self.confidenceThreshold {
                    detectTextRectangleObservations.append(observation)
                }
            }

            // text rectangle recognition
            try requestHandler.perform([textBoxRequests])

            var textObservationResults = [TextObservationResult]()
            for (observationIndex, observation) in detectTextRectangleObservations.enumerated() {

                // build and start processing of one observation
                let textBox = self.transform(observation: observation, in: image)
                if let croppedImage = image.crop(rectangle: textBox),
                    let cgImage = croppedImage.cgImage {

                    // text recognition (OCR)
                    let textRecognitionRequest = VNRecognizeTextRequest { (request, error) in

                        if let error = error {
                            Log.send(.error, "Error in text recognition.", extra: ["error": error.localizedDescription])
                            return
                        }

                        if let results = request.results,
                            !results.isEmpty {

                            for observation in (request.results as? [VNRecognizedTextObservation] ?? []) {
                                guard let candidate = observation.topCandidates(1).first,
                                    !candidate.string.isEmpty else { continue }

                                textObservationResults.append(TextObservationResult(rect: textBox, text: candidate.string))
                            }
                        }
                    }
                    // This doesn't require OCR on a live camera feed, select accurate for more accurate results.
                    textRecognitionRequest.recognitionLevel = .accurate
                    textRecognitionRequest.usesLanguageCorrection = true

                    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    try? handler.perform([textRecognitionRequest])
                }

                // update the progress view
                let progress = Float(Float(imageIndex) + Float(observationIndex) / Float(detectTextRectangleObservations.count)) / Float(sortedDocumentUrls.count)
                let borderedProgress = min(max(progress, 0), 1)
                progressHandler?(borderedProgress)
            }

            // append results
            textObservations.append(TextObservation(image: image, results: textObservationResults))
        }

        // save the pdf
        let document = PDFProcessing.renderPdf(from: textObservations)

        // save document
        let tempfilepath = tempImagePath.appendingPathComponent(documentId.uuidString).appendingPathExtension("pdf")
        document.write(to: tempfilepath)

        // delete original images
        for sortedDocumentUrl in sortedDocumentUrls {
            try? FileManager.default.removeItem(at: sortedDocumentUrl)
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

    private func assertAndLog(_ message: String, extra: [String: String] = [:]) {
        Log.send(.error, message, extra: extra)
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
