//
//  ImageConverter.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 05.03.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import Foundation
import os.log
import PDFKit
import SwiftyTesseract
import UIKit

extension Notification.Name {
    static var imageProcessingQueueLength: Notification.Name {
        return .init(rawValue: "ImageConverter.queueLength")
    }
}

public struct ImageConverter: Logging {

    private static let workerQueue: OperationQueue = {
        let workerQueue = OperationQueue()

        workerQueue.qualityOfService = .userInitiated
        workerQueue.name = (Bundle.main.bundleIdentifier ?? "PDFArchiver") + ".ImageConverter.workerQueue"
        workerQueue.maxConcurrentOperationCount = 1

        return workerQueue
    }()

    private static let languages: [RecognitionLanguage] = [.german, .english, .italian, .french, .swedish, .russian]
//    private static let languages: [RecognitionLanguage] = {
//        var langs: [RecognitionLanguage] = [.german, .english]
//
//        if Locale.current.identifier.starts(with: "it") {
//            langs.append(.italian)
//        } else if Locale.current.identifier.starts(with: "fr") {
//            langs.append(.french)
//        } else if Locale.current.identifier.starts(with: "sv") {
//            langs.append(.swedish)
//        } else if Locale.current.identifier.starts(with: "ru") {
//            langs.append(.russian)
//        }
//        return langs
//    }()

    public static func saveProcessAndSaveTempImages(at path: URL) {
        os_log("Start processing images", log: log, type: .debug)

        NotificationCenter.default.post(name: .imageProcessingQueueLength, object: workerQueue.operationCount + 1)
        let groupedPaths = StorageHelper.loadImages()
        guard !groupedPaths.isEmpty else {
            os_log("Could not find new images to process. Skipping ...", log: log, type: .info)
            return
        }

        for paths in groupedPaths {
            workerQueue.addOperation {

                // process one document as one operation, so that operationCount == numOfDocuments
                process(paths, saveAt: path)

                // notify after the pdf has been saved
                NotificationCenter.default.post(name: .imageProcessingQueueLength, object: workerQueue.operationCount - 1)
            }
        }
    }

    public static func getOperationCount() -> Int {
        return workerQueue.operationCount
    }

    private static func process(_ paths: [URL], saveAt path: URL) {

        // load image from file
        var images = [UIImage]()
        for path in paths {
            guard let image = getImage(from: path) else { fatalError("Could not get image at \(path).") }
            images.append(image)
        }

        // convert image to pdf
        let pdfDocument = createPDF(from: images)

        // generate filename by analysing the image
        let filename = getFilename(from: pdfDocument)
        let filepath = path.appendingPathComponent(filename)

        // save PDF document
        let success = save(pdfDocument, at: filepath)
        if success {
            for path in paths {
                try? FileManager.default.trashItem(at: path, resultingItemURL: nil)
            }
        } else {
            os_log("Document could not be saved.", log: log, type: .error)
        }
    }

    private static func createPDF(from images: [UIImage]) -> PDFDocument {
        os_log("Creating PDF from images", log: log, type: .debug)

        let document: PDFDocument

        let swiftyTesseract = SwiftyTesseract(languages: languages, bundle: .main, engineMode: .lstmOnly)

        // try to create a pdf document from
        let tmpData: Data?
        if #available(iOS 12.0, *) {
            let signpostID = OSSignpostID(log: log, object: images as AnyObject)
            os_signpost(.begin, log: log, name: "Process Images", signpostID: signpostID)
            tmpData = try? swiftyTesseract.createPDF(from: images)
            os_signpost(.end, log: log, name: "Process Images", signpostID: signpostID)
        } else {
            tmpData = try? swiftyTesseract.createPDF(from: images)
        }

        if let data = tmpData,
            let newDocument = PDFDocument(data: data) {
            document = newDocument

        } else {
            // Create an empty PDF document
            let newDocument = PDFDocument()

            for (index, image) in images.enumerated() {

                // Create a PDF page instance from the image
                guard let pdfPage = PDFPage(image: image) else { continue }

                // Insert the PDF page into your document
                newDocument.insert(pdfPage, at: index)
            }

            document = newDocument
        }

        return document
    }

    private static func getFilename(from document: PDFDocument) -> String {
        os_log("Creating filename", log: log, type: .debug)

        // get OCR content
        guard let content = document.string else { return "" }

        // parse the date
        let parsedDate = DateParser.parse(content)
        let date = parsedDate?.date ?? Date()

        // parse the tags
        var newTags = TagParser.parse(content)
        if newTags.isEmpty {
            newTags.insert("ocr")
            newTags.insert("scan")
        }

        // get default specification
        let specification = StorageHelper.Paths.documentDescriptionPlaceholder + Date().timeIntervalSince1970.description

        return Document.createFilename(date: date, specification: specification, tags: newTags)
    }

    private static func getImage(from path: URL) -> UIImage? {

        // Get the data from this file; exit if we fail
        guard let imageData = try? Data(contentsOf: path) else { return nil }

        // Get the image from this data; exit if we fail
        guard let image = UIImage(data: imageData) else { return nil }

        return image
    }

    private static func save(_ pdfDocument: PDFDocument, at path: URL) -> Bool {
        os_log("Saving PDF document", log: log, type: .debug)

        // check if the parent folder exists
        try? FileManager.default.createFolderIfNotExists(path.deletingLastPathComponent())

        // save PDF document
        guard let data = pdfDocument.dataRepresentation() else { return false }

        var success = false
        do {
            try data.write(to: path)
            success = true
        } catch {
            os_log("Failed to save pdf document: %@", log: log, type: .error, error.localizedDescription)
        }
        return success
    }
}
