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
import Vision

extension Notification.Name {
    static var imageProcessingQueue: Notification.Name {
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

        let groupedPaths = StorageHelper.loadImages()
        guard !groupedPaths.isEmpty else {
            os_log("Could not find new images to process. Skipping ...", log: log, type: .info)
            return
        }

        for paths in groupedPaths {

            NotificationCenter.default.post(name: .imageProcessingQueue, object: workerQueue.operationCount + 1)

            workerQueue.addOperation {
                let start = Date()
                Log.info("Process a document.")

                // process one document as one operation, so that operationCount == numOfDocuments
                do {
                    try process(paths, saveAt: path)
                } catch {
                    assertionFailure("Could not process images:\n\(error.localizedDescription)")
                    os_log("Could not process images.", log: log, type: .error)
                    Log.error("Could not process images.")
                    for path in paths {
                        try? FileManager.default.removeItem(at: path)
                    }
                }

                // notify after the pdf has been saved
                NotificationCenter.default.post(name: .imageProcessingQueue, object: workerQueue.operationCount - 1)
                let timeDiff = Date().timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate
                Log.info("Processing took \(timeDiff) seconds")
            }
        }
    }

    public static func getOperationCount() -> Int {
        return workerQueue.operationCount
    }

    private static func process(_ paths: [URL], saveAt path: URL) throws {

        guard !paths.isEmpty else {
            assertionFailure("Empty paths for processing.")
            return
        }

        // check if the parent folder exists
        try FileManager.default.createFolderIfNotExists(path)

        // load image from file
        var images = [UIImage]()
        for path in paths where path.pathExtension.lowercased() != "pdf" {
            guard let image = getImage(from: path) else { fatalError("Could not get image at \(path).") }
            images.append(image)
        }

        // convert image to pdf
        let tempFilepath = paths[0].deletingPathExtension().appendingPathExtension("pdf")
        createPDF(from: images, at: tempFilepath)

        // generate filename by analysing the image
        guard let pdfDocument = PDFDocument(url: tempFilepath) else { fatalError("Could not find PDF document.") }
        let filename = getFilename(from: pdfDocument)
        let filepath = path.appendingPathComponent(filename)

        // save PDF document and delete original images
        try FileManager.default.moveItem(at: tempFilepath, to: filepath)
        for path in paths {
            try? FileManager.default.removeItem(at: path)
        }
    }

    private static func createPDF(from images: [UIImage], at filepath: URL) {
        os_log("Creating PDF from images", log: log, type: .debug)

        let operation = PDFProcessing(images, documentSavePath: filepath)

        // try to create a pdf document from
        if #available(iOS 12.0, *) {
            let signpostID = OSSignpostID(log: log, object: images as AnyObject)
            os_signpost(.begin, log: log, name: "Process Images", signpostID: signpostID)
            operation.main()
            os_signpost(.end, log: log, name: "Process Images", signpostID: signpostID)
        } else {
            operation.main()
        }
    }

    private static func getFilename(from document: PDFDocument) -> String {
        os_log("Creating filename", log: log, type: .debug)

        // get OCR content
        guard let content = document.string else { return "" }

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

        // get default specification
        let specification = Constants.documentDescriptionPlaceholder + Date().timeIntervalSince1970.description

        return Document.createFilename(date: parsedDate, specification: specification, tags: newTags)
    }

    private static func getImage(from path: URL) -> UIImage? {

        // Get the data from this file; exit if we fail
        guard let imageData = try? Data(contentsOf: path) else { return nil }

        // Get the image from this data; exit if we fail
        guard let image = UIImage(data: imageData) else { return nil }

        return image
    }
}
