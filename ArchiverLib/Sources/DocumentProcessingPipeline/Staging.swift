//
//  Staging.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.26.
//

import Foundation
import OSLog

/// File handling for the staging folder — the crash-safe inbox of the
/// ``DocumentProcessor``.
///
/// Incoming requests are persisted here first and deleted only after the
/// finished document was written to the destination folder. Files that are
/// still here on the next launch (crash, terminated app) are simply picked up
/// again by the next staged-files run — there is no separate recovery
/// mechanism.
enum Staging {

    /// One processing request, backed by staged files.
    enum Batch: Sendable, Equatable {
        /// A single PDF file.
        case pdf(URL)
        /// Page images of one scan, in page order.
        case images([URL])

        var sourceUrls: [URL] {
            switch self {
            case .pdf(let url): [url]
            case .images(let urls): urls
            }
        }

        /// The staged file representing this request in progress events.
        var primarySource: URL? {
            sourceUrls.first
        }
    }

    private static let pageImageSeparator = "---"

    /// Persist scan page images (already JPEG encoded) with a shared UUID
    /// prefix, so an interrupted scan is recovered as ONE multi-page batch.
    static func persist(imageJpegs: [Data], in folder: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let uuid = UUID().uuidString
        var urls: [URL] = []
        do {
            for (index, data) in imageJpegs.enumerated() {
                let url = folder.appendingPathComponent("\(uuid)\(pageImageSeparator)\(index).jpg", isDirectory: false)
                try data.write(to: url)
                urls.append(url)
            }
        } catch {
            for url in urls {
                try? FileManager.default.removeItem(at: url)
            }
            throw error
        }
        return urls
    }

    /// Persist imported PDF data, keeping the original filename when possible.
    static func persist(pdfData: Data, filename: String?, in folder: URL) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        var name = filename ?? UUID().uuidString
        if !name.lowercased().hasSuffix(".pdf") {
            name += ".pdf"
        }

        var url = folder.appendingPathComponent(name, isDirectory: false)
        if FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(UUID().uuidString)-\(name)", isDirectory: false)
        }
        try pdfData.write(to: url)
        return url
    }

    /// Enumerate the staging folder (top level only) and group its files into
    /// processing batches: PDFs individually, page images by their scan UUID.
    static func batches(in folder: URL) -> [Batch] {
        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        } catch {
            // e.g. the folder does not exist yet because nothing was staged
            return []
        }

        var batches: [Batch] = []
        var scanPages: [String: [(index: Int, url: URL)]] = [:]

        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            switch url.pathExtension.lowercased() {
            case "pdf":
                batches.append(.pdf(url))

            case "jpg", "jpeg":
                let name = url.deletingPathExtension().lastPathComponent
                let components = name.components(separatedBy: pageImageSeparator)
                if components.count == 2,
                   let index = Int(components[1]) {
                    scanPages[components[0], default: []].append((index: index, url: url))
                } else {
                    // image from an unknown source (e.g. dropped into the
                    // folder directly) - treat as a one-page document
                    batches.append(.images([url]))
                }

            default:
                Logger.documentProcessor.debug("Ignoring unsupported staged file \(url.lastPathComponent, privacy: .public)")
            }
        }

        for (_, pages) in scanPages.sorted(by: { $0.key < $1.key }) {
            let orderedUrls = pages.sorted { $0.index < $1.index }.map(\.url)
            batches.append(.images(orderedUrls))
        }

        return batches
    }
}
