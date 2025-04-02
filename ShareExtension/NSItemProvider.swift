//
//  NSItemProvider.swift
//  
//
//  Created by Julian Kahnert on 28.12.20.
//

import Foundation
import PDFKit
import UniformTypeIdentifiers
#if os(macOS)
import AppKit.NSImage
private typealias Image = NSImage
#else
import UIKit.UIImage
private typealias Image = UIImage
#endif

extension NSItemProvider {
    enum NSItemProviderError: Error {
        case timeout
    }

    func saveData(at url: URL, with validUTIs: [UTType]) async throws -> Bool {
        var error: (any Error)?
        var data: Data?

        for uti in validUTIs where hasItemConformingToTypeIdentifier(uti.identifier) {
            do {
                data = try await getItem(for: uti)
            } catch let inputError {
                error = inputError
            }

            guard let data = data else { continue }

            if let image = Image(data: data),
                let imageData = image.jpg(quality: 1) {
                let fileUrl = url.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpeg")
                try imageData.write(to: fileUrl)
                return true
            } else if PDFDocument(data: data) != nil {
                let fileUrl = url.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
                try data.write(to: fileUrl)
                return true
            }
        }

        if let err = error {
            throw err
        }

        return false
    }

    private func getItem(for type: UTType) async throws -> Data? {
        let rawData = try await loadItem(forTypeIdentifier: type.identifier)

        if let pathData = rawData as? Data,
           let path = String(data: pathData, encoding: .utf8),
           let url = URL(string: path),
           let inputData = Self.getDataIfValid(from: url) {
            return inputData

        } else if let url = rawData as? URL,
                  let inputData = Self.getDataIfValid(from: url) {
            return inputData

        } else if let inputData = Self.validate(rawData as? Data) {
            return inputData

        } else if let image = rawData as? Image {
            return image.jpg(quality: 1)
        } else {
            return nil
        }
    }

    private static func getDataIfValid(from url: URL) -> Data? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return validate(data)
    }

    private static func validate(_ data: Data?) -> Data? {
        guard let inputData = data else { return data }
        if PDFDocument(data: inputData) == nil && Image(data: inputData) == nil {
            return nil
        }
        return inputData
    }
}

extension Image {
    func jpg(quality: CGFloat) -> Data? {
        #if os(macOS)
        // swiftlint:disable:next force_unwrapping
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: 1)])
        #else
        return jpegData(compressionQuality: 1)
        #endif
    }
}
