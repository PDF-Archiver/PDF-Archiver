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
import OSLog

#if canImport(UIKit)
import UIKit
private typealias Font = UIFont
private typealias Color = UIColor
private typealias DrawingOptions = NSStringDrawingOptions
#else
import AppKit
private typealias Font = NSFont
private typealias Color = NSColor
private typealias DrawingOptions = NSString.DrawingOptions
#endif

enum PDFProcessingError: Error {
    case untaggedDocumentsPathNotFound
}

final class PDFProcessingOperation: AsyncOperation {
    private static let log = Logger(subsystem: "processing", category: "pdf-processing-operation")
    private static let tempDocumentURL = Constants.tempDocumentURL
    private static let confidenceThreshold = Float(0)

    private let mode: Mode
    private let destinationFolder: URL
    private var tempUrls: [URL] = []
    

    private(set) var error: (any Error)?
    private(set) var outputUrl: URL?

    init(of mode: Mode, destinationFolder: URL) {
        self.mode = mode
        self.destinationFolder = destinationFolder
        
        
        Task {
            await save(mode)
        }
    }

    func process() async {
        do {
            guard !Task.isCancelled else { return }
            try FileManager.default.createFolderIfNotExists(destinationFolder)

            // signal the start of the operation
            let start = Date()
            Logger.documentProcessing.info("Process a document", metadata: ["filename": "\(mode)"])

            let document: PDFDocument
            switch mode {
            case .images(let images):

                // apply OCR and create a PDF
                document = try createPdf(from: images)
            case .pdf(let inputDocument):

                // just use the input PDF
                document = inputDocument
            }

            guard !Task.isCancelled else { return }
            
            // generate filename by analysing the image
            let filename = getFilename(from: document)
            let filepath = destinationFolder.appendingPathComponent(filename)
            document.write(to: filepath)

            self.outputUrl = filepath
            
            // delete original images
            for tempUrl in tempUrls {
                do {
                    try FileManager.default.removeItem(at: tempUrl)
                } catch {
                    Self.log.errorAndAssert("Failed to remove temp document", metadata: ["url" : tempUrl.path(), "error": "\(error)"])
                }
            }

            // log the processing time
            let timeDiff = Date().timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate
            Logger.documentProcessing.info("Process completed.", metadata: ["processing_time": "\(timeDiff)", "document_page_count": "\(document.pageCount)"])
        } catch {
            self.error = error
            Logger.documentProcessing.errorAndAssert("An error occurred while processing", metadata: ["error": "\(error)"])
        }
    }

    // MARK: - Helper Functions

    private func getFilename(from document: PDFDocument) -> String {
        if let documentUrl = document.documentURL,
           let parsedOutput = Document.parseFilename(documentUrl.lastPathComponent) as (date: Date?, specification: String?, tagNames: [String]?)?,
           parsedOutput.date != nil,
           let specification = parsedOutput.specification,
           specification != Constants.documentDescriptionPlaceholder {
            // the current filename of the document could be parsed and has no placeholders, so we use it
            return documentUrl.lastPathComponent
        } else {
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
    }

    private func createPdf(from images: [Image]) throws -> PDFDocument {
        var textObservations = [TextObservation]()
        for (imageIndex, image) in images.enumerated() {
            guard let cgImage = image.cgImage else { fatalError("Could not get cgImage") }
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            var detectTextRectangleObservations = [VNTextObservation]()
            let textBoxRequests = VNDetectTextRectanglesRequest { (request, error) in

                if let error = error {
                    Logger.documentProcessing.errorAndAssert("Error in text recognition.", metadata: ["error": "\(error)"])
                    return
                }

                for observation in (request.results as? [VNTextObservation] ?? []) where observation.confidence > Self.confidenceThreshold {
                    detectTextRectangleObservations.append(observation)
                }
            }

            // text rectangle recognition
            try requestHandler.perform([textBoxRequests])

            var textObservationResults = [TextObservationResult]()
            for (observationIndex, observation) in detectTextRectangleObservations.enumerated() {

                // build and start processing of one observation
                let textBox = self.transform(observation: observation, in: image.size)
                if let cgImage = cgImage.cropping(to: textBox) {

                    // text recognition (OCR)
                    let textRecognitionRequest = VNRecognizeTextRequest { (request, error) in

                        if let error = error {
                            Logger.documentProcessing.errorAndAssert("Error in text recognition.", metadata: ["error": "\(error)"])
                            return
                        }

                        if let results = request.results,
                            !results.isEmpty {
                            // Multiple observations are catenated
                            var thisObservation: [String] = []
                            for observation in (request.results as? [VNRecognizedTextObservation] ?? []) {
                                guard let candidate = observation.topCandidates(1).first,
                                    !candidate.string.isEmpty else { continue }
                                thisObservation.append(candidate.string)
                            }
                            let fullObservation = thisObservation.joined(separator: " ")
                            textObservationResults.append(TextObservationResult(rect: textBox, text: fullObservation))
                        }
                    }
                    // This doesn't require OCR on a live camera feed, select accurate for more accurate results.
                    textRecognitionRequest.recognitionLevel = .accurate
                    textRecognitionRequest.usesLanguageCorrection = true

                    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    try? handler.perform([textRecognitionRequest])
                }
            }

            // append results
            textObservations.append(TextObservation(image: image, results: textObservationResults))
        }

        // save the pdf
        let document = Self.renderPdf(from: textObservations)

        return document
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
    
    @StorageActor
    private func save(_ mode: Mode) {
        do {
            try FileManager.default.createFolderIfNotExists(Self.tempDocumentURL)
            
            switch mode {
            case .pdf(let document):
                let filename = document.documentURL?.lastPathComponent ?? UUID().uuidString
                let pdfUrl = Self.tempDocumentURL.appendingPathComponent(filename, isDirectory: false)
                document.write(to: pdfUrl)
                tempUrls = [pdfUrl]
                
            case .images(let images):
                var urls: [URL] = []
                do {
                    let uuid = UUID()
                    for (index, image) in images.enumerated() {
                        let filename = "\(index)---\(uuid.uuidString).jpg"
                        let imageUrl = Self.tempDocumentURL.appendingPathComponent(filename, isDirectory: false)
                        
                        try image.jpg(quality: 1)?.write(to: imageUrl)
                        urls.append(imageUrl)
                    }
                } catch {
                    for url in urls {
                        try? FileManager.default.removeItem(at: url)
                    }
                    throw error
                }
                tempUrls = urls
            }
        } catch {
            Self.log.errorAndAssert("Failed to save document", metadata: ["error" : "\(error)"])
        }
    }

    // MARK: - Helper Types

    enum Mode {
        case pdf(PDFDocument)
        case images([PlatformImage])
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
        let theFont = Font(named: fontName, fitting: text, into: size, with: attributes, options: .usesFontLeading)
        attributes[.font] = theFont
        let actualWidth = NSAttributedString(string: text, attributes: attributes).size()
        // Hack, 100% means leading and trailing font ligatures expand the drawing beyond the OCR box and the word gets
        // clipped. Since the font is scaled, there is no easy way to strip the spacing, but 1/4 the size of an average
        // char will work
        // swiftlint:disable:next identifier_name
        let em = actualWidth.width / CGFloat(text.count)
        attributes[NSAttributedString.Key.expansion] = log(size.width / (actualWidth.width + em / 4))

        return NSAttributedString(string: text, attributes: attributes)
    }
}
