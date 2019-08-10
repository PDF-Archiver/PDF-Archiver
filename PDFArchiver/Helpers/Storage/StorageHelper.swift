//
//  StorageHelper.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 11.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation
import PDFKit.PDFDocument
import UIKit.UIImage

enum StorageHelperError: Error {
    case invalidType
    case iCloudDriveNotFound
}

enum StorageHelper {

    private static let seperator = "----"

    static func handle(_ url: URL) throws {

        if let image = UIImage(contentsOfFile: url.path) {

            try StorageHelper.save([image])
            try StorageHelper.triggerProcessing()

        } else {
            ImageConverter.shared.processPdf(at: url)
        }
    }

    static func save(_ images: [UIImage]) throws {

        guard let tempImagePath = Paths.tempImagePath else { throw StorageError.noPathToSave }
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: tempImagePath.path) {
            try fileManager.createDirectory(at: tempImagePath, withIntermediateDirectories: true, attributes: nil)
        }

        let uuid = UUID()
        for (index, image) in images.enumerated() {
            // get jpg data from image
            guard let data = image.jpegData(compressionQuality: 0.8) else { throw StorageError.jpgConversion }

            // Attempt to write the data
            try data.write(to: tempImagePath.appendingPathComponent("\(uuid.uuidString)\(seperator)\(index).jpg"))
        }
    }

    static func loadImageIds() -> Set<UUID> {

        guard let tempImagePath = StorageHelper.Paths.tempImagePath else { fatalError("Could not find temp image path.") }

        let paths = (try? FileManager.default.contentsOfDirectory(at: tempImagePath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        let imageIds = paths
            .filter { $0.pathExtension.lowercased() != "pdf" }
            .compactMap { $0.lastPathComponent.components(separatedBy: seperator).first }
            .compactMap { UUID(uuidString: $0) }

        return Set(imageIds)
    }

    static func triggerProcessing() throws {
        guard let untaggedPath = StorageHelper.Paths.untaggedPath else { throw StorageHelperError.iCloudDriveNotFound }
        ImageConverter.shared.saveProcessAndSaveTempImages(at: untaggedPath)
    }

    // MARK: - Helper functions

    private static func getImagePaths() -> [URL] {

        guard let tempImagePath = StorageHelper.Paths.tempImagePath else { fatalError("Could not find temp image path.") }

        let paths = (try? FileManager.default.contentsOfDirectory(at: tempImagePath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        return paths.filter { $0.pathExtension.lowercased() != "pdf" }
    }
}
