//
//  StorageHelper.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 11.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation
import PDFKit.PDFDocument

public enum StorageHelper {

    private static let separator = "----"

    public static func save(_ images: [CIImage]) throws {

        try FileManager.default.createFolderIfNotExists(PathConstants.tempImageURL)

        let quality = CGFloat(UserDefaults.standard.pdfQuality.rawValue)
        let uuid = UUID()
        for (index, image) in images.enumerated() {
            guard let colorSpace = image.colorSpace else { throw StorageError.jpgConversion }

            // create a filename, e.g. 576951A0-88B9-44E4-B118-BDEC3556014A----0002.jpg
            let filename = "\(uuid.uuidString)\(separator)\(String(format: "%04d", index)).jpg"
            let url = PathConstants.tempImageURL.appendingPathComponent(filename)

            // Attempt to write image data to url
            try CIContext().writeJPEGRepresentation(of: image, to: url, colorSpace: colorSpace, options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality])
        }
    }

    public static func loadImageIds() -> Set<UUID> {

        let paths = (try? FileManager.default.contentsOfDirectory(at: PathConstants.tempImageURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        let imageIds = paths
            .filter { $0.pathExtension.lowercased() != "pdf" }
            .compactMap { $0.lastPathComponent.components(separatedBy: separator).first }
            .compactMap { UUID(uuidString: $0) }

        return Set(imageIds)
    }

    // MARK: - Helper functions

    private static func getImagePaths() -> [URL] {

        let paths = (try? FileManager.default.contentsOfDirectory(at: PathConstants.tempImageURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        return paths.filter { $0.pathExtension.lowercased() != "pdf" }
    }
}
