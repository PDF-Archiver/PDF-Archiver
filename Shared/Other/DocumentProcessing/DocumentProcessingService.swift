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
    private let backgroundProcessing = BackgroundProcessingActor<PDFProcessingOperation>()

    @MainActor
    private(set) var documentProgress: Float = 0
    @MainActor
    private(set) var progressLabel = ""
    @MainActor
    private(set) var totalDocumentCount = 0
    @MainActor
    private(set) var processedDocumentUrl: URL?

    private init() {
        triggerFolderObservation()
    }

    /// Fetch all documents in folder and test if PDF processing operations should be added.
    func triggerFolderObservation() {
//        handleFileChanges(at: Constants.tempDocumentURL)
    }

    func handle(_ images: [PlatformImage]) async {
        guard let destinationFolder = await getDocumentDestination() else {
            Logger.documentProcessing.errorAndAssert("Failed to get document")
            return
        }
        let operation = PDFProcessingOperation(of: .images(images), destinationFolder: destinationFolder)
        backgroundProcessing.queue(operation)
    }

    func handle(_ document: PDFDocument) async {
        guard let destinationFolder = await getDocumentDestination() else {
            Logger.documentProcessing.errorAndAssert("Failed to get document")
            return
        }
        let operation = PDFProcessingOperation(of: .pdf(document), destinationFolder: destinationFolder)
        backgroundProcessing.queue(operation)
    }

    @MainActor
    private func getDocumentDestination() -> URL? {
        do {
            return try PathManager.shared.getUntaggedUrl()
        } catch {
            Logger.documentProcessing.errorAndAssert("Could not get untagged folder URL", metadata: ["error": "\(error)"])
            return nil
        }
    }

    @MainActor
    private func updateProgress() async {
        #warning("TODO: implement this")
//        if operationCount > 0 {
//            let completedDocuments = totalDocumentCount - operationCount
//            let progressString = "\(min(completedDocuments + 1, totalDocumentCount))/\(totalDocumentCount) (\(Int(documentProgress * 100))%)"
//            self.documentProgress = Float(completedDocuments) / Float(totalDocumentCount)
//            self.progressLabel = NSLocalizedString("ScanViewController.processing", comment: "") + progressString
//        } else {
//            self.documentProgress = 0
//            self.progressLabel = NSLocalizedString("ScanViewController.processing", comment: "") + "0%"
//        }
    }

//    private func removeFromOperations(_ mode: PDFProcessing.Mode) {
//        operations.removeAll(where: { ($0.imageUUID != nil && $0.imageUUID == mode.imageUUID) || ($0.pdfUrl != nil && $0.pdfUrl == mode.pdfUrl) })
//    }
}
