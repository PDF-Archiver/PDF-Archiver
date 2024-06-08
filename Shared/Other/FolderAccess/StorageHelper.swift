//
//  StorageHelper.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 11.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation
import PDFKit.PDFDocument

@StorageActor
enum StorageHelper {

    private static let separator = "----"
    private static let tempDocumentURL = PathConstants.tempDocumentURL

    /// Save multiple images (e.g. multiple pages from document scan)
    static func save(_ images: [CIImage]) throws {

        try FileManager.default.createFolderIfNotExists(tempDocumentURL)

        let quality = CGFloat(UserDefaults.pdfQuality.rawValue)
        let uuid = UUID()
        for (index, image) in images.enumerated() {
            guard let colorSpace = image.colorSpace else { throw StorageError.jpgConversion }

            // create a filename, e.g. 576951A0-88B9-44E4-B118-BDEC3556014A----0002.jpg
            let filename = "\(uuid.uuidString)\(separator)\(String(format: "%04d", index)).jpg"
            let url = tempDocumentURL.appendingPathComponent(filename)

            // Attempt to write image data to url
            try CIContext().writeJPEGRepresentation(of: image, to: url, colorSpace: colorSpace, options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality])
        }
    }

    static func loadImageIds() -> Set<UUID> {

        let paths = (try? FileManager.default.contentsOfDirectory(at: tempDocumentURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        let imageIds = paths
            .filter { $0.pathExtension.lowercased() != "pdf" }
            .compactMap { $0.lastPathComponent.components(separatedBy: separator).first }
            .compactMap { UUID(uuidString: $0) }

        return Set(imageIds)
    }
}
