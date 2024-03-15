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

public extension NSItemProvider {
    enum NSItemProviderError: Error {
        case timeout
    }

    func saveData(at url: URL, with validUTIs: [UTType]) throws -> Bool {
        var error: Error?
        var data: Data?

        for uti in validUTIs where hasItemConformingToTypeIdentifier(uti.identifier) {
            do {
                data = try syncLoadItem(forTypeIdentifier: uti)
            } catch let inputError {
                error = inputError
            }

            guard let data = data else { continue }

            if Image(data: data) != nil {
                let fileUrl = url.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpeg")
                try data.write(to: fileUrl)
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

    func syncLoadItem(forTypeIdentifier uti: UTType) throws -> Data? {
        var data: Data?
        var error: Error?
        let semaphore = DispatchSemaphore(value: 0)
        self.loadItem(forTypeIdentifier: uti.identifier, options: nil) { rawData, rawError in
            defer {
                semaphore.signal()
            }
            if let rawError = rawError {
                error = rawError
            }

            if let pathData = rawData as? Data,
               let path = String(data: pathData, encoding: .utf8),
               let url = URL(string: path),
               let inputData = Self.getDataIfValid(from: url) {
                data = inputData

            } else if let url = rawData as? URL,
                      let inputData = Self.getDataIfValid(from: url) {
                data = inputData

            } else if let inputData = Self.validate(rawData as? Data) {
                data = inputData

            } else if let image = rawData as? Image {
                #if os(macOS)
                // swiftlint:disable:next force_unwrapping
                let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
                let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: 1)])
                #else
                data = image.jpegData(compressionQuality: 1)
                #endif
            }
        }
        let timeoutResult = semaphore.wait(timeout: .now() + .seconds(10))
        guard timeoutResult == .success else {
            throw NSItemProviderError.timeout
        }

        if let error = error {
            throw error
        }

        return data
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
