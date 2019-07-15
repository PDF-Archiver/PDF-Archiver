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

public class ImageConverter: Logging {

    static let shared = ImageConverter()

    private(set) var totalDocumentCount = 0
    private var observation: NSKeyValueObservation?
    private let workerQueue: OperationQueue = {
        let workerQueue = OperationQueue()

        workerQueue.qualityOfService = .userInitiated
        workerQueue.name = (Bundle.main.bundleIdentifier ?? "PDFArchiver") + ".ImageConverter.workerQueue"
        workerQueue.maxConcurrentOperationCount = 1

        return workerQueue
    }()

    private let languages: [RecognitionLanguage] = [.german, .english, .italian, .french, .swedish, .russian]
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

    private init() {}

    public func saveProcessAndSaveTempImages(at path: URL) {
        os_log("Start processing images", log: ImageConverter.log, type: .debug)

        let groupedPaths = StorageHelper.loadImages()
        guard !groupedPaths.isEmpty else {
            os_log("Could not find new images to process. Skipping ...", log: ImageConverter.log, type: .info)
            return
        }

        totalDocumentCount = groupedPaths.count
        for paths in groupedPaths {

            workerQueue.addOperation {
                let start = Date()
                Log.info("Process a document.")

                // process one document as one operation, so that operationCount == numOfDocuments
                do {
                    try self.process(paths, saveAt: path)
                } catch {
                    assertionFailure("Could not process images:\n\(error.localizedDescription)")
                    os_log("Could not process images.", log: ImageConverter.log, type: .error)
                    Log.error("Could not process images.")
                    for path in paths {
                        try? FileManager.default.removeItem(at: path)
                    }
                }

                // log the processing time
                let timeDiff = Date().timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate
                Log.info("Processing completed", extra: ["processing_time": timeDiff])
            }
        }

        observation = workerQueue.observe(\.operationCount, options: [.new]) { (_, change) in
            if change.newValue == nil || change.newValue == 0 {
                // Do something here when your queue has completed
                self.observation = nil

                // signal that all operations are done
                NotificationCenter.default.post(name: .imageProcessingQueue, object: nil)
                self.totalDocumentCount = 0
            }
        }
    }

    public func getOperationCount() -> Int {
        return workerQueue.operationCount
    }

    public func stopProcessing() {
        workerQueue.isSuspended = true
    }

    public func startProcessing() {
        workerQueue.isSuspended = false
    }

    private func process(_ paths: [URL], saveAt path: URL) throws {

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

    private func createPDF(from images: [UIImage], at filepath: URL) {
        os_log("Creating PDF from images", log: ImageConverter.log, type: .debug)

        let operation = PDFProcessing(images, documentSavePath: filepath) { progress in
            NotificationCenter.default.post(name: .imageProcessingQueue, object: progress)
        }

        // try to create a pdf document from
        if #available(iOS 12.0, *) {
            let signpostID = OSSignpostID(log: ImageConverter.log, object: images as AnyObject)
            os_signpost(.begin, log: ImageConverter.log, name: "Process Images", signpostID: signpostID)
            operation.main()
            os_signpost(.end, log: ImageConverter.log, name: "Process Images", signpostID: signpostID)
        } else {
            operation.main()
        }
    }

    private func getFilename(from document: PDFDocument) -> String {
        os_log("Creating filename", log: ImageConverter.log, type: .debug)

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

    private func getImage(from path: URL) -> UIImage? {

        // Get the data from this file; exit if we fail
        guard let imageData = try? Data(contentsOf: path) else { return nil }

        // Get the image from this data; exit if we fail
        guard let image = UIImage(data: imageData) else { return nil }

        return image
    }
}
