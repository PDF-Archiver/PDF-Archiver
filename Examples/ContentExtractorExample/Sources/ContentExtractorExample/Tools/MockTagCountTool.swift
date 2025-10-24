//
//  MockTagCountTool.swift
//  ContentExtractorExample
//
//  Mock implementation of TagCountTool using hardcoded data instead of real ArchiveStore
//

import Foundation
import FoundationModels

@available(iOS 26, macOS 26, *)
struct MockTagCountTool: Tool {
    let name = "getTags"
    let description = "Get already used tags and their counts."

    @Generable
    struct Arguments {
        @Guide(description: "Minimum number of tag count - default: 3")
        var minTagCount: Int?
    }

    func call(arguments: Arguments) async throws -> String {
        // Mock data: frequently used tags
        let mockTagCounts: [(name: String, count: Int)] = [
            (name: "invoice", count: 45),
            (name: "contract", count: 32),
            (name: "insurance", count: 28),
            (name: "bank", count: 25),
            (name: "tax", count: 22),
            (name: "salary", count: 18),
            (name: "rent", count: 15),
            (name: "car", count: 12),
            (name: "doctor", count: 10),
            (name: "internet", count: 8),
            (name: "electricity", count: 7),
            (name: "mobile", count: 6),
            (name: "shipping", count: 5),
            (name: "clothing", count: 4),
            (name: "electronics", count: 3)
        ]

        let minCount = arguments.minTagCount ?? 3
        let filteredTags = mockTagCounts.filter { $0.count >= minCount }

        let formattedTagCounts = filteredTags
            .prefix(30)
            .map { "'\($0.name)': \($0.count)" }

        return """
        'tagName': count
        \(formattedTagCounts.joined(separator: "\n"))
        """
    }
}
