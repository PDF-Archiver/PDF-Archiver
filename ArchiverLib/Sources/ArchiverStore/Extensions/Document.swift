//
//  Document.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 08.07.25.
//

import ArchiverModels
import Foundation
import OSLog

extension Document {
    static func create(url: URL, isTagged: Bool, downloadStatus: Double, sizeInBytes: Double) async -> Document? {
        guard let id = url.uniqueId() else {
            Logger.archiveStore.errorAndAssert("Failed to get uniqueId")
            return nil
        }
        guard let filename = url.filename() else {
            Logger.archiveStore.errorAndAssert("Failed to get filename")
            return nil
        }

        let data = await Document.parseFilename(filename)
        let tags = Set(data.tagNames ?? [])

        let date = data.date ?? url.fileCreationDate() ?? Date()
        let specification = isTagged ? (data.specification ?? "n/a").replacingOccurrences(of: "-", with: " ") : (data.specification ?? "n/a")

        return Document(id: id,
                        url: url,
                        date: date,
                        specification: specification,
                        tags: tags,
                        isTagged: isTagged,
                        sizeInBytes: sizeInBytes,
                        downloadStatus: downloadStatus)
    }
}
