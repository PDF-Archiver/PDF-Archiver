//
//  StorageHelper.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 11.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation
import UIKit.UIImage

enum StorageHelper {

    private static let seperator = "----"

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

    static func loadImages() -> [[URL]] {

        let tempImagePaths = getImagePaths()
        let uuids = Set(tempImagePaths.compactMap { $0.lastPathComponent.components(separatedBy: seperator).first })

        var groupedPaths = [[URL]]()
        for uuid in uuids {

            // select images with the same id
            let documentPaths = tempImagePaths.filter { $0.lastPathComponent.starts(with: String(uuid)) }
            guard !documentPaths.isEmpty else { fatalError("Could not find images for id \(uuid) in paths:\n\(tempImagePaths)") }
            groupedPaths.append(documentPaths)
        }

        return groupedPaths
    }

    // MARK: - Helper functions

    private static func getImagePaths() -> [URL] {

        guard let tempImagePath = StorageHelper.Paths.tempImagePath else { fatalError("Could not find temp image path.") }

        let paths = (try? FileManager.default.contentsOfDirectory(at: tempImagePath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        return paths.filter { $0.pathExtension.lowercased() != "pdf" }
    }
}
