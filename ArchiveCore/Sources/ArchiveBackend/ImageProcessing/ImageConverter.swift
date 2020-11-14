//
//  ImageConverter.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 05.03.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ErrorHandling
import Foundation
import PDFKit
import Vision

public protocol ImageConverterDelegate: class {
    func getDocumentDestination() -> URL?
}

public final class ImageConverter: ObservableObject, ImageConverterAPI, Log {

    @Published public private(set) var error: Error?

    private static let seperator = "----"
    private static var isInitialized = false

    public private(set) var totalDocumentCount = Atomic(0)
    private var observation: NSKeyValueObservation?
    private let getDocumentDestination: () -> URL?
    private let queue: OperationQueue = {
        let queue = OperationQueue()

        queue.qualityOfService = .userInitiated
        queue.name = (Bundle.main.bundleIdentifier ?? "PDFArchiver") + ".ImageConverter.workerQueue"
        queue.maxConcurrentOperationCount = 1

        return queue
    }()

    public init(getDocumentDestination: @escaping () -> URL?, shouldStartBackgroundTask: Bool) {
        precondition(!Self.isInitialized, "ImageConverter must only initialized once.")
        Self.isInitialized = true
        self.getDocumentDestination = getDocumentDestination

        // move files from the temp folder to the current destination
        if let destinationFolder = getDocumentDestination(),
           destinationFolder != PathManager.tempPdfURL {
            do {
                let documentUrls = try FileManager.default.contentsOfDirectory(at: PathManager.tempPdfURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
                    .filter { $0.pathExtension.lowercased().hasSuffix("pdf") }
                for documentUrl in documentUrls {
                    let destinationUrl = destinationFolder.appendingPathComponent(documentUrl.lastPathComponent)
                    try FileManager.default.moveItem(at: documentUrl, to: destinationUrl)
                }
            } catch {
                log.errorAndAssert("Error while moving files.", metadata: ["error": "\(error)"])
            }
        }

        #if os(iOS)
        // by setting the delegate, the BackgroundTaskScheduler will be initialized
        if shouldStartBackgroundTask {
            BackgroundTaskScheduler.shared.delegate = self
        }
        #endif
    }

    public func handle(_ url: URL) throws {

        if let image = CIImage(contentsOf: url) {
            try StorageHelper.save([image])
            guard let destinationURL = getDocumentDestination() else { throw StorageError.noPathToSave }
            saveProcessAndSaveTempImages(at: destinationURL)
            try FileManager.default.removeItem(at: url)
        } else if url.pathExtension.lowercased() == "pdf" {
            addOperation(with: .pdf(url))
        } else {
            throw StorageError.wrongExtension(url.pathExtension)
        }
    }

    public func getOperationCount() -> Int {
        return queue.operationCount
    }

    public func startProcessing() throws {
        queue.isSuspended = false

        guard let destinationURL = getDocumentDestination() else { throw StorageError.noPathToSave }
        saveProcessAndSaveTempImages(at: destinationURL)
    }

    public func stopProcessing() {
        queue.isSuspended = true
    }

    private func saveProcessAndSaveTempImages(at path: URL) {
        log.debug("Start processing images")

        let currentlyProcessingImageIds = queue.operations.compactMap { ($0 as? PDFProcessing)?.documentId }
        let imageIds = StorageHelper.loadImageIds().subtracting(currentlyProcessingImageIds)
        guard !imageIds.isEmpty else {
            log.info("Could not find new images to process. Skipping ...")
            return
        }

        imageIds.forEach { addOperation(with: .images($0)) }
    }

    private func addOperation(with mode: PDFProcessing.Mode) {
        triggerObservation()

        guard let destinationURL = getDocumentDestination() else {
            self.error = AlertDataModel.createAndPost(title: "Attention",
                                                      message: "Failed to get destination path.",
                                                      primaryButtonTitle: "OK")
            return
        }

        let availableTags = TagStore.shared.getAvailableTags(with: [])
        let operation = PDFProcessing(of: mode,
                                      destinationFolder: destinationURL,
                                      tempImagePath: PathManager.tempImageURL,
                                      archiveTags: availableTags) { progress in
            NotificationCenter.default.post(name: .imageProcessingQueue, object: progress)
        }
        operation.completionBlock = {
            guard let error = operation.error else { return }
            DispatchQueue.main.async {
                self.error = error
            }
        }
        queue.addOperation(operation)
        totalDocumentCount.mutate { $0 += 1 }
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

extension ImageConverter: BackgroundTaskExecutionDelegate {
    public func executeBackgroundTask(completion: @escaping ((Bool) -> Void)) {
        try? startProcessing()

        #if DEBUG
        UserNotification.schedule(title: "Start PDF processing", message: "Operations left in queue: \(queue.operationCount)")
        #endif

        // this execution block will only run on a background task, so no UI affects should happen
        queue.addOperation { [weak self] in
            guard let self = self else { return }
            completion(self.queue.operationCount < 2)
        }
    }
}
