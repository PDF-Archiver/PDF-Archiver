//
//  PDFProcessing.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 18.06.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable cyclomatic_complexity function_body_length

import GraphicsRenderer
import PDFKit
import Vision

#if canImport(UIKit)
import UIKit
private typealias Image = UIImage
private typealias Font = UIFont
private typealias Color = UIColor
private typealias DrawingOptions = NSStringDrawingOptions
#else
import AppKit
private typealias Image = NSImage
private typealias Font = NSFont
private typealias Color = NSColor
private typealias DrawingOptions = NSString.DrawingOptions
extension NSImage {
    var cgImage: CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
#endif

public enum PDFProcessingError: Error {
    case untaggedDocumentsPathNotFound
    case pdfNotFound
}

public final class PDFProcessing: Operation, Log {

    public typealias ProgressHandler = ((Float) -> Void)

    private let mode: Mode
    private let destinationFolder: URL
    private let tempImagePath: URL
    private let progressHandler: ProgressHandler?
    private let confidenceThreshold = Float(0)

    public private(set) var error: Error?
    public private(set) var outputUrl: URL?
    public var documentId: UUID? {
        if case Mode.images(let documentId) = mode {
            return documentId
        } else {
            return nil
        }
    }

    public init(of mode: Mode, destinationFolder: URL, tempImagePath: URL, progressHandler: ProgressHandler?) {
        self.mode = mode
        self.destinationFolder = destinationFolder
        self.tempImagePath = tempImagePath
        self.progressHandler = progressHandler
    }

    override public func main() {

        do {
            if isCancelled {
                return
            }
            try FileManager.default.createFolderIfNotExists(destinationFolder)

            // signal the start of the operation
            let start = Date()
            log.info("Process a document.")
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
            let filename = getFilename(from: document)
            let filepath = destinationFolder.appendingPathComponent(filename)

            try FileManager.default.moveItem(at: path, to: filepath)
            self.outputUrl = filepath

            // log the processing time
            let timeDiff = Date().timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate
            log.info("Process completed.", metadata: ["processing_time": "\(timeDiff)", "document_page_count": "\(document.pageCount)"])
            progressHandler?(Float(1))
        } catch let error {
            self.error = error
        }
    }

    // MARK: - Helper Functions

    private func getFilename(from document: PDFDocument) -> String {

        // get default specification
        let specification = Constants.documentDescriptionPlaceholder + Date().timeIntervalSince1970.description

        // get OCR content
        var content = ""
        for pageNumber in 0..<min(document.pageCount, 3) {
            guard content.count < 5000 else { break }
            content += document.page(at: pageNumber)?.string ?? ""
        }

        // use the default filename if no content could be found
        guard !content.isEmpty else {
            return Document.createFilename(date: Date(), specification: specification, tags: Set([Constants.documentTagPlaceholder]))
        }

        // parse the date
        let parsedDate = DateParser.parse(content)?.date ?? Date()

        // parse the tags
        let tags = Set([Constants.documentTagPlaceholder])
        return Document.createFilename(date: parsedDate, specification: specification, tags: tags)
    }

    private func createPdf(of documentId: UUID) throws -> URL {
        // check if the parent folder exists
        try FileManager.default.createFolderIfNotExists(tempImagePath)

        // STEP I: get all image urls
        let allImageUrls = (try? FileManager.default.contentsOfDirectory(at: tempImagePath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])) ?? []

        // STEP II: filter and sort those urls in a second step to avoid shuffling around pages
        let sortedDocumentUrls = allImageUrls
            .filter { $0.lastPathComponent.starts(with: documentId.uuidString) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var textObservations = [TextObservation]()
        for (imageIndex, imageUrl) in sortedDocumentUrls.enumerated() {

            guard let image = Image(contentsOfFile: imageUrl.path) else {
                fatalError("Could not find image at \(imageUrl.path)")
            }

            guard let cgImage = image.cgImage else { fatalError("Could not get the cgImage.") }
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            var detectTextRectangleObservations = [VNTextObservation]()
            let textBoxRequests = VNDetectTextRectanglesRequest { (request, error) in

                if let error = error {
                    Self.log.error("Error in text recognition.", metadata: ["error": "\(error)"])
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
                let textBox = self.transform(observation: observation, in: image.size)
                if let cgImage = image.cgImage?.cropping(to: textBox) {

                    // text recognition (OCR)
                    let textRecognitionRequest = VNRecognizeTextRequest { (request, error) in

                        if let error = error {
                            Self.log.error("Error in text recognition.", metadata: ["error": "\(error)"])
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

        var pages = [PDFPage]()
        for observation in observations {

            // create context - we use different contexts in order to get different page sizes in the PDF
            var bounds = CGRect(origin: .zero, size: observation.image.size)
            let data = NSMutableData()
            // swiftlint:disable force_unwrapping
            let consumer = CGDataConsumer(data: data)!
            let context = CGContext(consumer: consumer, mediaBox: &bounds, nil)!
            // swiftlint:enable force_unwrapping

            #if os(macOS)
                let previousContext = NSGraphicsContext.current
                NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            #else
                UIGraphicsPushContext(context)
            #endif
            var info = [String: Any]()
            info[kCGPDFContextMediaBox as String] = bounds
            let pageInfo = info as CFDictionary
            context.beginPDFPage(pageInfo)

            let transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: bounds.height)
            context.concatenate(transform)

            // save data in context
            observation.image.draw(in: bounds)
            for result in observation.results {
                result.attributedText.draw(in: result.rect)
            }

            // close context
            context.endPDFPage()
            context.closePDF()
            #if os(macOS)
                NSGraphicsContext.current = previousContext
            #else
                UIGraphicsPopContext()
            #endif

            // extract pdf from context
            guard let document = PDFDocument(data: data as Data),
                  let page = document.page(at: 0) else { fatalError("Could not generate PDF document.") }
            pages.append(page)
        }

        // merge pages
        let document = PDFDocument()
        for (index, page) in pages.enumerated() {
            document.insert(page, at: index)
        }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        document.documentAttributes?[PDFDocumentAttribute.creatorAttribute] = "PDF Archiver " + (version ?? "")
        return document
    }

    private func transform(observation: VNTextObservation, in imageSize: CGSize) -> CGRect {

        // special thanks to: https://github.com/g-r-a-n-t/serial-vision/
        var transform = CGAffineTransform.identity
        transform = transform.scaledBy(x: imageSize.width, y: -imageSize.height)
        transform = transform.translatedBy(x: 0, y: -1 )

        return CGRect(x: observation.boundingBox.applying(transform).origin.x,
                      y: observation.boundingBox.applying(transform).origin.y,
                      width: observation.boundingBox.applying(transform).width,
                      height: observation.boundingBox.applying(transform).height)
    }

    // MARK: - Helper Types

    public enum Mode {
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
        let image: Image
        let results: [TextObservationResult]
    }

}

extension Font {
    fileprivate convenience init?(named fontName: String, fitting text: String, into targetSize: CGSize, with attributes: [NSAttributedString.Key: Any], options: DrawingOptions) {
        var attributes = attributes
        let fontSize = targetSize.height

        attributes[.font] = Font(name: fontName, size: fontSize)
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

        let fontName = Font.systemFont(ofSize: 0).fontName
        var attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.foregroundColor: Color.clear]
        attributes[.font] = Font(named: fontName, fitting: text, into: size, with: attributes, options: .usesFontLeading)

        return NSAttributedString(string: text, attributes: attributes)
    }
}
