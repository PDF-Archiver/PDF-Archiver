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

    private(set) var totalDocumentCount = Atomic(0)
    private var observation: NSKeyValueObservation?
    private let queue: OperationQueue = {
        let queue = OperationQueue()

        queue.qualityOfService = .userInitiated
        queue.name = (Bundle.main.bundleIdentifier ?? "PDFArchiver") + ".ImageConverter.workerQueue"
        queue.maxConcurrentOperationCount = 1

        return queue
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

        if queue.operationCount == 0 {
            observation = queue.observe(\.operationCount, options: [.new]) { (_, change) in
                if change.newValue == nil || change.newValue == 0 {
                    // Do something here when your queue has completed
                    self.observation = nil

                    // signal that all operations are done
                    NotificationCenter.default.post(name: .imageProcessingQueue, object: nil)
                    self.totalDocumentCount.mutate { $0 = 0 }
                }
            }
        }

        let currentlyProcessingImageIds = queue.operations.compactMap { ($0 as? PDFProcessing)?.documentId }
        let imageIds = StorageHelper.loadImageIds().subtracting(currentlyProcessingImageIds)
        guard !imageIds.isEmpty else {
            os_log("Could not find new images to process. Skipping ...", log: ImageConverter.log, type: .info)
            return
        }

        for imageId in imageIds {

            let operation = PDFProcessing(of: imageId) { progress in
                NotificationCenter.default.post(name: .imageProcessingQueue, object: progress)
            }
            queue.addOperation(operation)
            totalDocumentCount.mutate { $0 += 1 }
        }
    }

    public func getOperationCount() -> Int {
        return queue.operationCount
    }

    public func stopProcessing() {
        queue.isSuspended = true
    }

    public func startProcessing() {
        queue.isSuspended = false
    }
}
