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

    private let session: LanguageModelSession

    init() {
        let tagCountTool = MockTagCountTool()
        let documentDescriptionTool = MockDocumentDescriptionTool()

        session = LanguageModelSession(
            model: .default,
            tools: [tagCountTool], // TODO: no tool calls will happen when documentDescriptionTool is active
            instructions: Instructions {

            // Task description
            """
            Your task is to archive documents by analyzing their content and generating appropriate descriptions and tags.
            """

            // Document tags:
            """
            Tags MUST prioritize existing tags from the system whenever applicable.
            Use the \(tagCountTool.name) tool to query available tags and their usage frequency.
            Prefer frequently used tags to maintain consistency.
            If no suitable existing tags are found, create new appropriate tags.
            """

            // Document description:
            """
            The description should provide a concise summary of the document's content.
            You MUST ALWAYS use the user's locale: \(Self.locale.identifier).
            """

            """
            You MUST ALWAYS retrieve example descriptions using the \(documentDescriptionTool.name) tool.
            Model your new description after the examples, adapting the style and format to match the current document's content.
            """

            // Example:
            """
            For an invoice for a blue jumper from Tom Tailor, the ideal output would be:
            - Description: Blue hoodie
            - Tags: invoice, clothing, tomtailor
            """
            })
    }

    func prewarm() {
        session.prewarm()
    }

    @MainActor
    func extract(from text: String, customPrompt: String? = nil) async throws -> LanguageModelSession.Response<DocumentInformation>? {

        // as of iOS 26.0 we can not cancel in flight responses, so we have to return early, if a request is currently running
        guard !session.isResponding else { return nil }

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
}

extension ExampleContentExtractorStore {

}
