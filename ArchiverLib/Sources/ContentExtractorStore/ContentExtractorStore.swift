//
//  ContentExtractorStore.swift
//  ArchiveLib
//
//  Created by Julian Kahnert on 20.11.18.
//

import ArchiverModels
import Foundation
import FoundationModels
import OSLog

@available(iOS 26, macOS 26, *)
public actor ContentExtractorStore {

    /// Test seam: turn the context documents + custom prompt + document text into
    /// raw, un-normalized model output. The live implementation calls the
    /// on-device model; tests inject a deterministic stub.
    typealias Responder = @Sendable (_ documents: [Document], _ customPrompt: String?, _ text: String) async throws -> RawDocumentInformation

    // `sampling:` is deprecated in the macOS 27 SDK but the only spelling the
    // macOS 26 SDK has, and CI builds against that one - renaming breaks it.
    private static let options = GenerationOptions(
        sampling: .greedy,
        temperature: 0.0,
        maximumResponseTokens: 512
    )

    /// Maximum number of characters of the user's custom prompt.
    ///
    /// The settings UI caps its input with this value and the prompt builder
    /// truncates with it, so the character counter never promises more than what
    /// actually reaches the model.
    public static var maxCustomPromptLength: Int {
        ContentExtractionPromptFactory.maxCustomPromptLength(contextSize: SystemLanguageModel.default.contextSize)
    }

    private let cache: ContentExtractorCache
    private let availability: @Sendable () -> AppleIntelligenceAvailability
    private let respond: Responder

    public init() {
        self.init(cache: ContentExtractorCache(),
                  availability: { Self.getAvailability() },
                  respond: Self.liveResponder)
    }

    /// Designated initializer. Internal seams let tests exercise the cache and
    /// mapping orchestration deterministically, without Apple Intelligence.
    init(cache: ContentExtractorCache,
         availability: @escaping @Sendable () -> AppleIntelligenceAvailability,
         respond: @escaping Responder) {
        self.cache = cache
        self.availability = availability
        self.respond = respond
    }

    public static func getAvailability() -> AppleIntelligenceAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available

        case .unavailable:
            return .unavailable

        @unknown default:
            return .unavailable
        }
    }

    /// Extract document information using Apple Intelligence
    /// - Parameters:
    ///   - text: The document text content to analyze
    ///   - customPrompt: Optional custom prompt to guide the extraction
    ///   - documents: Existing documents for context (tags, specifications)
    ///   - documentId: Optional document ID for caching results
    /// - Returns: Extracted specification and tags, or nil if unavailable or if
    ///   the document text is not readable
    public func extract(from text: String, customPrompt: String? = nil, with documents: [Document], documentId: Document.ID? = nil) async throws -> Info? {
        guard availability().isUsable else { return nil }

        // Asked to summarize mojibake, the model describes it ("Unlesbarer
        // Dokumententext"). Before the cache read, so stale entries go too.
        guard TextReadability.isReadable(text) else {
            Logger.contentExtractor.info("Skipping extraction, document text is not readable")
            return nil
        }

        // Check cache if document ID is provided
        if let documentId,
           let cachedEntry = await cache.getCachedResult(for: documentId) {
            Logger.contentExtractor.info("Using cached result for document ID: \(documentId)")
            return Info(specification: cachedEntry.specification, tags: cachedEntry.tags)
        }

        let raw = try await respond(documents, customPrompt, text)
        let vocabulary = Set(documents.flatMap(\.tags).map { $0.lowercased() })
        let normalized = ContentExtractionMapper.normalize(raw, vocabulary: vocabulary)
        let info = Info(specification: normalized.specification, tags: normalized.tags)

        // Save result to cache for faster subsequent access
        if let documentId {
            let cacheEntry = ContentExtractorCache.CacheEntry(
                documentId: documentId,
                specification: info.specification,
                tags: info.tags
            )
            await cache.saveCacheEntry(cacheEntry)
        }

        return info
    }

    // MARK: - Cache Management

    /// Clear all cache entries
    public func clearCache() async {
        await cache.clearCache()
    }

    /// Get the number of cache entries
    public func getCacheCount() async -> Int {
        await cache.getCacheCount()
    }

    /// Process untagged documents in the background to create cache entries
    /// This method should be called when the device is idle and connected to power
    /// - Parameters:
    ///   - documents: All documents to process
    ///   - textExtractor: Closure to extract text from document URL
    ///   - customPrompt: Optional custom prompt for extraction
    public func processUntaggedDocumentsInBackground(documents: [Document], textExtractor: (URL) async -> String?, customPrompt: String?) async -> Int {
        // Only process untagged documents
        let untaggedDocuments = documents.filter { !$0.isTagged }

        Logger.contentExtractor.info("Background cache processing started for \(untaggedDocuments.count) untagged documents")

        var newCachesCreated = 0

        for document in untaggedDocuments {
            guard !Task.isCancelled else { break }

            let documentId = document.id

            // Skip if already cached
            if await cache.getCachedResult(for: documentId) != nil {
                continue
            }

            // Extract text and process (cache will be saved inside extract())
            guard let text = await textExtractor(document.url) else {
                Logger.contentExtractor.info("Skipping document without extractable text (e.g. not downloaded yet) - document ID: \(documentId)")
                continue
            }

            do {
                let info = try await extract(from: text,
                                             customPrompt: customPrompt,
                                             with: documents,
                                             documentId: documentId)
                if info != nil {
                    newCachesCreated += 1
                    Logger.contentExtractor.debug("Background cache entry created for document ID: \(documentId)")
                } else {
                    // e.g. the language model is currently not available
                    Logger.contentExtractor.info("No cache entry created for document ID: \(documentId)")
                }
            } catch {
                Logger.contentExtractor.error("Failed to create cache entry in background for document ID \(documentId): \(error)")
            }
        }

        // Prune cache entries for documents that no longer exist in untagged folder.
        // Never prune while the document list is empty (e.g. the store has not finished
        // loading) - that would wipe all valid cache entries.
        if !documents.isEmpty {
            let untaggedIds = Set(untaggedDocuments.map(\.id))
            await cache.pruneCache(keepingOnly: untaggedIds)
        }

        Logger.contentExtractor.info("Background cache processing completed: \(newCachesCreated) new caches created")

        return newCachesCreated
    }

    // MARK: - Live model call

    /// The production responder: build a session from the prompt factory's
    /// instruction segments and run the on-device model. This is the only place
    /// that touches FoundationModels generation.
    private static let liveResponder: Responder = { documents, customPrompt, text in
        let session = LanguageModelSession(model: .default, tools: [], instructions: instructions(for: documents))
        let model = SystemLanguageModel.default
        let contextSize = model.contextSize

        let customPrompt = ContentExtractionPromptFactory.truncatedCustomPrompt(
            customPrompt,
            maxLength: maxCustomPromptLength
        )
        let customPromptLength = customPrompt?.count ?? 0
        var truncatedText = ContentExtractionPromptFactory.truncatedText(
            from: text,
            customPromptLength: customPromptLength,
            budget: ContentExtractionPromptFactory.promptBudget(contextSize: contextSize)
        )

        // The estimated budget is pessimistic, so ask the tokenizer what the
        // first cut really costs and re-cut with the measured ratio. A dense
        // tail can break that ratio, so the longer cut only counts if it fits.
        if truncatedText.count < text.count,
           #available(iOS 26.4, macOS 26.4, *) {
            do {
                let sampleTokens = try await model.tokenCount(for: Prompt(truncatedText))
                let recut = ContentExtractionPromptFactory.truncatedText(
                    from: text,
                    customPromptLength: customPromptLength,
                    budget: ContentExtractionPromptFactory.calibratedBudget(contextSize: contextSize,
                                                                           sampleLength: truncatedText.count,
                                                                           sampleTokens: sampleTokens)
                )
                if try await model.tokenCount(for: Prompt(recut)) <= ContentExtractionPromptFactory.availableTokens(contextSize: contextSize) {
                    truncatedText = recut
                }
            } catch {
                Logger.contentExtractor.error("Failed to measure the token count, keeping the estimate: \(error)")
            }
        }

        let prompt = Prompt {
            customPrompt ?? ""
            """
            document content:\n\(truncatedText)
            """
        }

        let response = try await session.respond(
            to: prompt,
            generating: DocumentInformation.self,
            includeSchemaInPrompt: true,
            options: options
        )

        return RawDocumentInformation(description: response.content.description,
                                      tags: response.content.tags)
    }

    /// The instruction segments the live extraction runs with, so a capability
    /// report or an evaluation measures the prompt the app actually sends.
    public static func instructions(for documents: [Document]) -> Instructions {
        let stats = ContentExtractionPromptFactory.documentStats(from: documents)
        let locale = ContentExtractionPromptFactory.promptLocale
        return Instructions {
            ContentExtractionPromptFactory.taskInstruction
            ContentExtractionPromptFactory.descriptionInstruction(stats: stats, locale: locale)
            ContentExtractionPromptFactory.tagsInstruction(stats: stats, locale: locale)
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
extension ContentExtractorStore {
    @Generable
    struct DocumentInformation {
        @Guide(description: "short document description")
        var description: String

        @Guide(description: "document tags; lowercase; no symbols", .maximumCount(ContentExtractionMapper.maxTags))
        var tags: [String]
    }

    public struct Info: Sendable, Equatable {
        public let specification: String
        public let tags: [String]
    }
}
