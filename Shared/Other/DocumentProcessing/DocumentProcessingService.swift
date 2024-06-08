//
//  ImageConverter.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 05.03.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation
import PDFKit
import Vision
import OSLog

@StorageActor
@Observable
final class DocumentProcessingService {

    static let shared = DocumentProcessingService()
    
    @MainActor
    private(set) var documentProgress: Float = 0
    @MainActor
    private(set) var progressLabel = ""
    @MainActor
    private(set) var totalDocumentCount = 0
    @MainActor
    private(set) var processedDocumentUrl: URL?
    @MainActor
    private var operationCount: Int {
        return queue.operationCount
    }
    
    private var operations: [PDFProcessing.Mode] = []
    private let queue: OperationQueue = {
        let queue = OperationQueue()

        queue.qualityOfService = .background
        queue.name = (Bundle.main.bundleIdentifier ?? "PDFArchiver") + ".DocumentProcessingService.workerQueue"
        queue.maxConcurrentOperationCount = 1

        return queue
    }()

    private init() {
        triggerFolderObservation()
        
        #if !APPCLIP && !os(macOS)
        // by setting the delegate, the BackgroundTaskScheduler will be initialized
        BackgroundTaskScheduler.shared.delegate = self
        #endif
    }
    
    /// Fetch all documents in folder and test if PDF processing operations should be added.
    func triggerFolderObservation() {
        handleFileChanges(at: PathConstants.tempDocumentURL)
    }
    
//    func startProcessing() throws {
//        queue.isSuspended = false
//    }
//
//    // we stop the current processing when scanning a document
//    func stopProcessing() {
//        #warning("TODO: do we need to stop the processing in background mode?")
//        queue.isSuspended = true
//    }
    
    private func handleFileChanges(at url: URL) {
        Logger.documentProcessing.trace("Change in url", metadata: ["url": "\(url.path())"])
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            
            // get pdf documents
            let pdfUrls = urls.filter { $0.lastPathComponent.lowercased().hasSuffix("pdf") }
            let urlsInOperations = operations.compactMap(\.pdfUrl)
            for pdfUrl in Set(pdfUrls).subtracting(Set(urlsInOperations)) {
                addOperation(with: .pdf(pdfUrl))
            }
            
            // get images
            let imageIds = StorageHelper.loadImageIds()
            let imageUUIDsInOperations = operations.compactMap(\.imageUUID)
            for imageId in Set(imageIds).subtracting(imageUUIDsInOperations) {
                addOperation(with: .images(imageId))
            }
            
        } catch {
            Logger.documentProcessing.errorAndAssert("Failed ", metadata: ["error": "\(error)"])
        }
    }
    
    private func getDocumentDestination() -> URL? {
        do {
            return try PathManager.shared.getUntaggedUrl()
        } catch {
            Logger.documentProcessing.errorAndAssert("Could not get untagged folder URL", metadata: ["error": "\(error)"])
            return nil
        }
    }

    private func addOperation(with mode: PDFProcessing.Mode) {
        if queue.operationCount == 0 {
            Task {
                await MainActor.run {
                    totalDocumentCount = 0
                }
            }
        }
        
        operations.append(mode)
        guard let destinationURL = getDocumentDestination() else {
            NotificationCenter.default.createAndPost(title: "Attention",
                                                     message: "Failed to get destination path.",
                                                     primaryButtonTitle: "OK")
            return
        }

        let operation = PDFProcessing(of: mode,
                                      destinationFolder: destinationURL,
                                      tempImagePath: PathConstants.tempDocumentURL)
        operation.completionBlock = { [weak self] in
            Logger.documentProcessing.trace("Finished processing document", metadata: ["filename": operation.outputUrl?.lastPathComponent ?? ""])
            Task { [weak self] in
                await self?.removeFromOperations(mode)
                await MainActor.run { [weak self] in
                    self?.processedDocumentUrl = operation.outputUrl
                }
                await self?.updateProgress()
            }

            if let error = operation.error {
                NotificationCenter.default.postAlert(error)
            }
        }
        Task {
            await MainActor.run {
                totalDocumentCount += 1
            }
        }
        queue.addOperation(operation)
    }
    
    @MainActor
    private func updateProgress() async {
        if operationCount > 0 {
            let completedDocuments = totalDocumentCount - operationCount
            let progressString = "\(min(completedDocuments + 1, totalDocumentCount))/\(totalDocumentCount) (\(Int(documentProgress * 100))%)"
            self.documentProgress = Float(completedDocuments) / Float(totalDocumentCount)
            self.progressLabel = NSLocalizedString("ScanViewController.processing", comment: "") + progressString
        } else {
            self.documentProgress = 0
            self.progressLabel = NSLocalizedString("ScanViewController.processing", comment: "") + "0%"
        }
    }
    
    private func removeFromOperations(_ mode: PDFProcessing.Mode) {
        operations.removeAll(where: { ($0.imageUUID != nil && $0.imageUUID == mode.imageUUID) || ($0.pdfUrl != nil && $0.pdfUrl == mode.pdfUrl) })
    }
}

extension DocumentProcessingService: BackgroundTaskExecutionDelegate {
    func executeBackgroundTask(completion: @escaping ((Bool) -> Void)) {
        #warning("TODO: do we need this?")
//        try? startProcessing()

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
