//
//  ImageConverter.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 05.03.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation
import OSLog
import PDFKit
import Shared
import Vision

@StorageActor
@Observable
public final class DocumentProcessingService: Sendable {

    public private(set) var lastProcessedDocumentUrl: URL?
    private let tempDocumentURL: URL
    private let documentDestination: () async throws -> URL?
    private let backgroundProcessing = BackgroundProcessingActor<PDFProcessingOperation>()
    /// Prevents concurrent `triggerObservation()` calls from re-processing files
    /// that are still being handled by a prior invocation.
    private var isObserving = false

    public init(tempDocumentURL: URL, documentDestination: @escaping @Sendable () async throws -> URL?) {
        self.tempDocumentURL = tempDocumentURL
        self.documentDestination = documentDestination

        // Recover before any processing operation of this session could have
        // written a working copy - files in the processing subfolder are
        // guaranteed to be orphans of an interrupted run at this point.
        recoverOrphanedProcessingFiles()
    }

    /// Fetch all documents in folder and test if PDF processing operations should be added.
    public func triggerObservation() async {
        guard !isObserving else {
            Logger.documentProcessing.debug("Skipping folder observation, already in progress")
            return
        }
        isObserving = true
        defer { isObserving = false }
        await self.handleFolderContents(at: self.tempDocumentURL)
    }

    public func handle(_ images: [PlatformImage]) async -> URL? {
        guard let destinationFolder = await getDocumentDestination() else {
            Logger.documentProcessing.errorAndAssert("Failed to get document")
            return nil
        }

        return await withCheckedContinuation { continuation in
            let operation = PDFProcessingOperation(of: .images(images), destinationFolder: destinationFolder, onComplete: { documentUrl in
                self.lastProcessedDocumentUrl = documentUrl
                continuation.resume(returning: documentUrl)
            })
            backgroundProcessing.queue(operation)
        }
    }

    public func handle(_ pdfData: Data, url: URL?) async {
        guard let destinationFolder = await getDocumentDestination() else {
            Logger.documentProcessing.errorAndAssert("Failed to get document")
            return
        }
        let operation = PDFProcessingOperation(of: .pdf(pdfData: pdfData, url: url), destinationFolder: destinationFolder, onComplete: { documentUrl in
            self.lastProcessedDocumentUrl = documentUrl ?? self.lastProcessedDocumentUrl
        })
        backgroundProcessing.queue(operation)
    }

    /// Move files that were left behind in the processing subfolder (e.g. because
    /// the app was terminated mid-processing) back into the observed temp folder,
    /// so the next folder observation imports them again.
    private func recoverOrphanedProcessingFiles() {
        let processingFolder = tempDocumentURL.appendingPathComponent(Constants.processingTempFolderName)
        guard FileManager.default.directoryExists(at: processingFolder) else { return }

        do {
            let orphanedUrls = try FileManager.default.contentsOfDirectory(at: processingFolder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            for orphanedUrl in orphanedUrls {
                var destinationUrl = tempDocumentURL.appendingPathComponent(orphanedUrl.lastPathComponent)
                if FileManager.default.fileExists(atPath: destinationUrl.path) {
                    destinationUrl = tempDocumentURL.appendingPathComponent("\(UUID().uuidString)-\(orphanedUrl.lastPathComponent)")
                }
                do {
                    try FileManager.default.moveItem(at: orphanedUrl, to: destinationUrl)
                    Logger.documentProcessing.info("Recovered orphaned document from processing folder", metadata: ["file": "\(orphanedUrl.lastPathComponent)"])
                } catch {
                    Logger.documentProcessing.errorAndAssert("Failed to recover orphaned document", metadata: ["url": orphanedUrl.path(), "error": "\(error)"])
                }
            }
        } catch {
            Logger.documentProcessing.errorAndAssert("Failed to read processing folder", metadata: ["error": "\(error)"])
        }
    }

    private func getDocumentDestination() async -> URL? {
        do {
            return try await documentDestination()
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

            let pdfUrls = Set(urls.filter { $0.pathExtension.lowercased() == "pdf" })
            let imageUrls = Set(urls.filter { ["jpg", "jpeg"].contains($0.pathExtension.lowercased()) })

            await withTaskGroup(of: Void.self) { group in
                for pdfUrl in pdfUrls {
                    guard let document = PDFDocument(url: pdfUrl) else {
                        Logger.documentProcessing.errorAndAssert("Failed to create PDFDocument \(pdfUrl.path())")
                        continue
                    }
                    group.addTask {
                        guard let destinationFolder = await self.getDocumentDestination(),
                            let pdfData = document.dataRepresentation() else {
                            Logger.documentProcessing.errorAndAssert("Failed to get document")
                            return
                        }
                        let operation = await PDFProcessingOperation(of: .pdf(pdfData: pdfData, url: document.documentURL), destinationFolder: destinationFolder, onComplete: { _ in })
                        self.backgroundProcessing.queue(operation)
                        // The operation keeps its own working copy in the processing
                        // subfolder, so the original must be removed - otherwise it
                        // would be imported again on the next folder observation.
                        try? FileManager.default.removeItem(at: pdfUrl)
                    }
                }

                for imageUrl in imageUrls {
                    do {
                        let data = try Data(contentsOf: imageUrl)
                        group.addTask {
                            guard let image = PlatformImage(data: data) else { return }
                            _ = await self.handle([image])
                            // Delete the original image file. PDFProcessingOperation.save()
                            // creates separate temp copies (.jpg) that are cleaned up by the
                            // operation itself. Without this, the original .jpeg persists and
                            // gets re-processed on every triggerObservation() call.
                            try? FileManager.default.removeItem(at: imageUrl)
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
