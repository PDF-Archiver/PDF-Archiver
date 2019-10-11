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
import UIKit
import Vision

extension Notification.Name {
    static var imageProcessingQueue: Notification.Name {
        return .init(rawValue: "ImageConverter.queueLength")
    }
}

public class ImageConverter: SystemLogging {

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

    private init() {}

    public func saveProcessAndSaveTempImages(at path: URL) {
        os_log("Start processing images", log: ImageConverter.log, type: .debug)

        let currentlyProcessingImageIds = queue.operations.compactMap { ($0 as? PDFProcessing)?.documentId }
        let imageIds = StorageHelper.loadImageIds().subtracting(currentlyProcessingImageIds)
        guard !imageIds.isEmpty else {
            os_log("Could not find new images to process. Skipping ...", log: ImageConverter.log, type: .info)
            return
        }

        imageIds.forEach { addOperation(with: .images($0)) }
    }

    public func processPdf(at path: URL) {
        addOperation(with: .pdf(path))
    }

    private func addOperation(with mode: PDFProcessing.Mode) {
        triggerObservation()
        let operation = PDFProcessing(of: mode) { progress in
            NotificationCenter.default.post(name: .imageProcessingQueue, object: progress)
        }
        operation.completionBlock = {
            guard let error = operation.error else { return }
            UIAlertController.create(with: error)
        }
        queue.addOperation(operation)
        totalDocumentCount.mutate { $0 += 1 }
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

    private func triggerObservation() {
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
    }
}
