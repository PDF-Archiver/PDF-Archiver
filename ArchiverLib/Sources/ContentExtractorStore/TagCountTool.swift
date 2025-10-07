//
//  TagCountTool.swift
//  
//
//  Created by Julian Kahnert on 16.09.25.
//

import ArchiverStore
import Dependencies
import FoundationModels

@available(iOS 26, macOS 26, *)
struct TagCountTool: Tool {
    @Dependency(\.archiveStore) var archiveStore

    let name = "getTags"
    let description = "Get already used tags and their counts."

    @Generable
    struct Arguments {
        @Guide(description: "Minimum number of tag count - default: 3")
        var minTagCount: Int?
    }

    func call(arguments: Arguments) async throws -> String {
        let documents = try await archiveStore.getDocuments()

        let tagCounts = Dictionary(grouping: documents.flatMap(\.tags)) {
            $0
        }
            .map { (name: $0, count: $1.count) }
            .filter { $0.count >= (arguments.minTagCount ?? 3) }

//        let tagCounts: [String: Int] = [
//            "rechnung": 20,
//            "kleidung": 2,
//            "auto": 122,
//        ]

        let formattedTagCounts = tagCounts
            .prefix(30)
            .map {
            "'\($0.0)': \($0.1)"
            }
        return """
        'tagName': count
        \(formattedTagCounts)
        """
    }
}
