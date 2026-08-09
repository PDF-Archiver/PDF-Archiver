//
//  DemoFileProvider.swift
//
//
//  Created by Julian Kahnert on 08.01.21.
//

import ArchiverModels
import CoreGraphics
import Foundation
import Shared

#if DEBUG
final class DemoFolderProvider: FolderProvider, Log {
    private static var isInitialized = false
    static func canHandle(_ url: URL) -> Bool {
        true
    }

    let baseUrl: URL
    let currentDocumentsStream: AsyncStream<[DocumentInformation]>
    private let currentDocumentsStreamContinuation:
        AsyncStream<[DocumentInformation]>.Continuation

    init(baseUrl: URL) throws {
        self.baseUrl = baseUrl

        let (stream, continuation) = AsyncStream.makeStream(of: [DocumentInformation].self)
        currentDocumentsStream = stream
        currentDocumentsStreamContinuation = continuation

        guard !Self.isInitialized,
            baseUrl.lastPathComponent != "untagged" else { throw DemoFolderProviderError.alreadyInitialized }
        initialize()
        Self.isInitialized = true
    }

    func save(data: Data, at: URL) throws {
        log.debug("save(data: Data, at: URL) throws")
    }

    func startDownload(of: URL) throws {
        log.debug("startDownload(of: URL) throws")
    }

    func fetch(url: URL) throws -> Data {
        log.debug("fetch(url: URL) throws -> Data")
        return Data()
    }

    func delete(url: URL) throws {
        log.debug("delete(url: URL) throws")
    }

    func stop() {}

    func rename(from: URL, to: URL) throws {
        log.debug("rename(from: URL, to: URL) throws")
    }

    /// Every demo document must exist on disk: `Document.create` derives its id from the file and
    /// drops documents whose file is missing.
    private static let relativePaths = [
        "untagged/2021 01 08 - scan1.pdf",
        "2024/2024-05-12--electricity-bill__bill_electricity.pdf",
        "2024/2024-09-03--rental-contract__contract_flat.pdf",
        "2025/2025-02-18--invoice-laptop__bill_hardware.pdf"
    ]

    private func initialize() {
        // The bundled example-bill.pdf was dropped along with the old app target, so demo mode
        // draws its own sample instead of force unwrapping a resource that no longer ships.
        let bundledSample = Bundle.main.url(forResource: "example-bill", withExtension: "pdf")

        let urls = Self.relativePaths.map { baseUrl.appendingPathComponent($0) }
        for url in urls where !FileManager.default.fileExists(atPath: url.path()) {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

            if let bundledSample {
                try? FileManager.default.copyItem(at: bundledSample, to: url)
            } else {
                Self.writeSamplePDF(to: url)
            }
        }

        currentDocumentsStreamContinuation.yield(
            urls.map { DocumentInformation(url: $0, downloadStatus: 1, sizeInBytes: 1000) })
    }

    /// Draws a one page invoice-ish document from plain rectangles - enough for the demo archive to
    /// show something in the PDF view without shipping a binary asset.
    private static func writeSamplePDF(to url: URL) {
        var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            log.errorAndAssert("Could not create PDF context for demo document")
            return
        }

        context.beginPDFPage(nil)

        context.setFillColor(gray: 1, alpha: 1)
        context.fill(mediaBox)

        context.setFillColor(gray: 0.2, alpha: 1)
        context.fill(CGRect(x: 60, y: 720, width: 280, height: 24))

        context.setFillColor(gray: 0.75, alpha: 1)
        for index in 0..<20 {
            let isParagraphEnd = index % 5 == 4
            context.fill(CGRect(x: 60, y: 660 - CGFloat(index) * 30, width: isParagraphEnd ? 210 : 475, height: 11))
        }

        context.endPDFPage()
        context.closePDF()
    }
}

private enum DemoFolderProviderError: String, Error {
    case alreadyInitialized
}
#endif
