//
//  CloudExtraction.swift
//  ContentExtractorStoreTests
//

// `canImport` for the macOS 26 SDK of CI, which has no Evaluations module at
// all; `@available` for this package's macOS 15 floor - on each declaration and
// never on the `@Suite`, which the macro rejects (swift-testing#608).
#if os(macOS) && canImport(Evaluations)

import ArchiverModels
import Foundation
import FoundationModels

@testable import ContentExtractorStore

/// Runs the shipped extraction instructions through Private Cloud Compute, to
/// measure what the app gives up by staying on device.
///
/// Two things change at once if the whole document is sent, so the text cut is
/// a separate switch: Private Cloud Compute has 32768 tokens where the
/// on-device model has 4096, and it also is the larger model.
@available(macOS 27, *)
enum CloudExtraction {

    /// Character cut the on-device path applies, so a run can hold the context
    /// window fixed and vary only the model.
    static let onDeviceTextLimit = 4750

    /// - Parameter pageSources: Sample text -> filename, so the responder can
    ///   attach the page that was pre-rendered for it. The image is what makes
    ///   this worth measuring: without it Private Cloud Compute leaves one or
    ///   two documents unanswered.
    static func responder(sendsWholeDocument: Bool,
                          pageSources: [String: String]) -> ContentExtractorStore.Responder {
        { documents, customPrompt, text in
            let pageImage = pageSources[text].flatMap(PageImage.url(for:))
            let session = LanguageModelSession(model: PrivateCloudComputeLanguageModel(),
                                               instructions: ContentExtractorStore.instructions(for: documents))
            let body = sendsWholeDocument ? text : String(text.prefix(onDeviceTextLimit))
            let prompt = Prompt {
                customPrompt ?? ""
                """
                document content:\n\(body)
                """
                if let pageImage {
                    Attachment(imageURL: pageImage).label("first page")
                }
            }

            let response = try await session.respond(
                to: prompt,
                generating: ContentExtractorStore.DocumentInformation.self,
                includeSchemaInPrompt: true,
                options: GenerationOptions(sampling: .greedy, temperature: 0.0, maximumResponseTokens: 512)
            )
            return RawDocumentInformation(description: response.content.description,
                                          tags: response.content.tags)
        }
    }
}

#endif
