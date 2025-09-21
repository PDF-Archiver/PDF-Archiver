//
//  DescriptionTool.swift
//
//
//  Created by Julian Kahnert on 16.09.25.
//

import ArchiverStore
import Dependencies
import FoundationModels

@available(iOS 26, macOS 26, *)
struct DescriptionTool: Tool {
    @Dependency(\.archiveStore) var archiveStore

    let name = "getDescriptions"
    let description = "Get previously used document descriptions."

    @Generable
    struct Arguments {
        @Guide(description: "Maximum number of descriptions", .range(1...100))
        var maxCount: Int
    }

    func call(arguments: Arguments) async throws -> [String] {
        let documents = try await archiveStore.getDocuments()

        return documents.sorted { $0.date > $1.date }
            .prefix(arguments.maxCount)
            .map(\.specification)
    }
}
