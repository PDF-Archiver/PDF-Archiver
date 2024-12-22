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
    private var backgroundProcessingIds = Set<String>()

//    @MainActor
//    private(set) var documentProgress: Float = 0
//    @MainActor
//    private(set) var progressLabel = ""
//    @MainActor
//    private(set) var totalDocumentCount = 0
//    @MainActor
//    private(set) var processedDocumentUrl: URL?

    private init() {
        triggerFolderObservation()
    }

    /// Fetch all documents in folder and test if PDF processing operations should be added.
    func triggerFolderObservation() {
        Task.detached(priority: .background) {
            await self.handleFolderContents(at: Constants.tempDocumentURL)
        }
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

    private func handleFolderContents(at url: URL) async {
        Logger.documentProcessing.trace("Check files in url", metadata: ["url": "\(url.path())"])

        guard FileManager.default.directoryExists(at: url) else {
            Logger.documentProcessing.info("Folder does not exist")
            return
        }

        do {
            let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])

            let pdfUrls = Set(urls.filter { $0.lastPathComponent.lowercased().hasSuffix("pdf") })
            let imageUrls = Set(urls.filter { $0.lastPathComponent.lowercased().hasSuffix("jpeg") })

            await withTaskGroup(of: Void.self) { group in
                for pdfUrl in pdfUrls {
                    guard let document = PDFDocument(url: pdfUrl) else {
                        Logger.documentProcessing.errorAndAssert("Failed to create PDFDocument \(pdfUrl.path())")
                        continue
                    }
                    group.addTask {
                        await self.handle(document)
                    }
                }

                for imageUrl in imageUrls {
                    do {
                        let data = try Data(contentsOf: imageUrl)
                        guard let image = PlatformImage(data: data) else { continue }
                        group.addTask {
                            await self.handle([image])
                        }
                    } catch {
                        Logger.documentProcessing.errorAndAssert("Failed to create Image \(imageUrl.path())", metadata: ["error": "\(error)"])
                    }
                }
            }

        } catch {
            Logger.documentProcessing.errorAndAssert("Failed ", metadata: ["error": "\(error)"])
        }
    }
}
