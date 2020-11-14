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

    private static let seperator = "----"

    public static func save(_ images: [CIImage]) throws {

        try FileManager.default.createFolderIfNotExists(PathManager.tempImageURL)

        let quality = CGFloat(UserDefaults.standard.pdfQuality.rawValue)
        let uuid = UUID()
        for (index, image) in images.enumerated() {

            // get jpg data from image
            guard let data = image.jpegData(compressionQuality: quality) else { throw StorageError.jpgConversion }

            // create a filename, e.g. 576951A0-88B9-44E4-B118-BDEC3556014A----0002.jpg
            let filename = "\(uuid.uuidString)\(seperator)\(String(format: "%04d", index)).jpg"

            // Attempt to write the data
            try data.write(to: PathManager.tempImageURL.appendingPathComponent(filename))
        }
    }

    public static func loadImageIds() -> Set<UUID> {

        let paths = (try? FileManager.default.contentsOfDirectory(at: PathManager.tempImageURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        let imageIds = paths
            .filter { $0.pathExtension.lowercased() != "pdf" }
            .compactMap { $0.lastPathComponent.components(separatedBy: seperator).first }
            .compactMap { UUID(uuidString: $0) }

        return Set(imageIds)
    }

    // MARK: - Helper functions

    private static func getImagePaths() -> [URL] {

        let paths = (try? FileManager.default.contentsOfDirectory(at: PathManager.tempImageURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        return paths.filter { $0.pathExtension.lowercased() != "pdf" }
    }
}
