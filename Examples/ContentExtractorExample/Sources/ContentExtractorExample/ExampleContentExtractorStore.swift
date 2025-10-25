//
//  ExampleContentExtractorStore.swift
//  ContentExtractorExample
//
//  Minimal example of ContentExtractorStore using mock data
//

import Foundation
import FoundationModels

@Generable
struct DocumentInformation {
    @Guide(description: "short document description")
    var description: String

    @Guide(description: "document tags; lowercase; no symbols", .maximumCount(10))
    var tags: [String]
}

actor ExampleContentExtractorStore {
    private static let maxTotalPromptLength = 3500

    private static var locale: Locale {
        Locale.current.region == "DE" ? Locale(identifier: "de_DE") : Locale.current
    }

    private static let options = GenerationOptions(
        sampling: .greedy,
        temperature: 0.0,
        maximumResponseTokens: 512
    )

    @MainActor
    func extract(from text: String, customPrompt: String? = nil) async throws -> LanguageModelSession.Response<DocumentInformation>? {

        let session = Self.createSession()

        let availableTextLength = Self.maxTotalPromptLength - (customPrompt?.count ?? 0)
        let truncatedText = String(text.prefix(max(0, availableTextLength)))

        let prompt = Prompt {
            customPrompt ?? ""
            """
            document content:\n\(truncatedText)
            """
        }

        let response = try await session.respond(
            to: prompt,
            generating: DocumentInformation.self,
            includeSchemaInPrompt: false,
            options: Self.options
        )

        return response
    }

    // MARK: - internal helper functions

    private static func createSession() -> LanguageModelSession {
        let docStats = getMockDocumentStats()
        return LanguageModelSession(
            model: .default,
            tools: [],
            instructions: Instructions {

            // Task description
            """
            Your task is to archive documents by analyzing their content and generating appropriate descriptions and tags.
            """

            // Document tags:
            """
            Tags MUST ALWAYS use existing tags from the system whenever applicable.
            Prefer frequently used tags to maintain consistency: \(docStats.tagCounts)
            If no suitable existing tags are found, create new appropriate tags.
            """

            // Document description:
            """
            The description should provide a concise summary of the document's content (5-10 words maximum).
            You MUST ALWAYS use the user's locale: \(Self.locale.identifier).
            You MUST ALWAYS model your new description after the examples, adapting the style and format to match the current document's content.
            Only use the current document content. DO NOT hallucinate.
            Example descriptions: \(docStats.specifications)
            """

            // Example:
            """
            For an invoice for a blue jumper from Tom Tailor, the ideal output would be:
            - Description: Blue hoodie
            - Tags: invoice, clothing, tomtailor
            """
            })
    }

    private struct DocStats {
        let tagCounts: String
        let specifications: String
    }

    private static func getMockDocumentStats() -> DocStats {
        // Mock data: frequently used tags
        let mockTagCounts = [
            "'invoice': 45",
            "'contract': 32",
            "'insurance': 28",
            "'bank': 25",
            "'tax': 22",
            "'salary': 18",
            "'rent': 15",
            "'car': 12",
            "'doctor': 10",
            "'internet': 8",
            "'electricity': 7",
            "'mobile': 6",
            "'shipping': 5",
            "'clothing': 4",
            "'electronics': 3"
        ]

        let tagCountsString = """
        'tagName': count
        \(mockTagCounts.joined(separator: "\n"))
        """

        // Mock document descriptions
        let mockDescriptions = [
            "blue-hoodie",
            "insurance-letter",
            "tax-relevant",
            "income-tax"
        ]

        let specificationsString = mockDescriptions.joined(separator: "\n")

        return DocStats(tagCounts: tagCountsString,
                        specifications: specificationsString)
    }
}

extension ExampleContentExtractorStore {

}
