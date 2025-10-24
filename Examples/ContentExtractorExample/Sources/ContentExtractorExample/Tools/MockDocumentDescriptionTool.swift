//
//  MockDocumentDescriptionTool.swift
//  ContentExtractorExample
//
//  Created by Julian Kahnert on 24.10.25.
//

import FoundationModels

struct MockDocumentDescriptionTool: Tool {
    let name = "getDescriptions"
    let description = "Get previously used document descriptions."

    @Generable
    struct Arguments {
        @Guide(description: "Maximum number of descriptions", .range(1...100))
        var maxCount: Int
    }

    func call(arguments: Arguments) async throws -> [String] {
        let mockDescriptions = [
            "blue-hoodie",
            "insurance-letter",
            "tax-relevant",
            "income-tax"
        ]

        return Array(mockDescriptions.prefix(arguments.maxCount))
    }
}
