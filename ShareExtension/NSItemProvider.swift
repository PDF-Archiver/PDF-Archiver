//
//  NSItemProvider.swift
//
//
//  Created by Julian Kahnert on 28.12.20.
//

import ArchiverModels
import Foundation
import PDFKit
import Shared
import UIKit
import UniformTypeIdentifiers

extension NSItemProvider {
    enum NSItemProviderError: Error {
        case timeout
    }

    func saveData(at url: URL, with validUTIs: [UTType]) async throws -> Bool {
        var lastError: (any Error)?
        var data: Data?
        var sourceURL: URL?

        for uti in validUTIs where hasItemConformingToTypeIdentifier(uti.identifier) {
            do {
                (data, sourceURL) = try await getItem(for: uti)
            } catch {
                lastError = error
            }

            guard let data else { continue }

            if let image = UIImage(data: data),
               let imageData = image.normalizedOrientation().jpegData(compressionQuality: 1) {
                let fileUrl = url.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpeg")
                // The app's processor polls this folder; it must never pick up a half-written file.
                try imageData.write(to: fileUrl, options: .atomic)
                return true
            } else if PDFDocument(data: data) != nil {
                // For PDFs, preserve filename only if it has valid structure with tags/description
                let filename: String
                if let originalFilename = sourceURL?.lastPathComponent,
                   await Self.isValidTaggedFilename(originalFilename) {
                    filename = originalFilename
                } else {
                    filename = UUID().uuidString + ".pdf"
                }
                var fileUrl = url.appendingPathComponent(filename)
                // Same scheme as `Staging.persist`: two shares with one tagged name must both arrive.
                if FileManager.default.fileExists(atPath: fileUrl.path) {
                    fileUrl = url.appendingPathComponent("\(UUID().uuidString)-\(filename)")
                }
                try data.write(to: fileUrl, options: .atomic)
                return true
            }
        }

        if let lastError {
            throw lastError
        }

        return false
    }

    /// Validates if a filename has the correct PDF Archiver structure with date, description, and tags
    private static func isValidTaggedFilename(_ filename: String) async -> Bool {
        let parsed = await Document.parseFilename(filename)

        // Valid if we have date, specification, and tags (all non-nil and non-empty)
        guard parsed.date != nil,
              let spec = parsed.specification,
              !spec.isEmpty,
              let tags = parsed.tagNames,
              !tags.isEmpty else {
            return false
        }

        return true
    }

    private func getItem(for type: UTType) async throws -> (Data?, URL?) {
        let rawData = try await loadItem(forTypeIdentifier: type.identifier)

        if let pathData = rawData as? Data,
           let path = String(data: pathData, encoding: .utf8),
           let url = URL(string: path),
           let inputData = Self.getDataIfValid(from: url) {
            return (inputData, url)
        } else if let url = rawData as? URL,
                  let inputData = Self.getDataIfValid(from: url) {
            return (inputData, url)
        } else if let inputData = Self.validate(rawData as? Data) {
            return (inputData, nil)
        } else if let image = rawData as? UIImage {
            return (image.jpegData(compressionQuality: 1), nil)
        } else {
            return (nil, nil)
        }
    }

    private static func getDataIfValid(from url: URL) -> Data? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return validate(data)
    }

    private static func validate(_ data: Data?) -> Data? {
        guard let inputData = data else { return data }
        if PDFDocument(data: inputData) == nil, UIImage(data: inputData) == nil {
            return nil
        }
        return inputData
    }
}

extension NSItemProvider.NSItemProviderError: LogSafeError {
    var logDescription: String { "\(self)" }
}

private extension UIImage {
    /// Bake the EXIF orientation into the bitmap: the processor runs OCR on `cgImage`,
    /// which ignores it, so a sideways photo would get text boxes for an upright page.
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        // Keep the photo's pixel size; the default display scale would triple it and
        // exceed the extension's memory limit on a camera photo.
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
