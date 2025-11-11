//
//  ContentExtractorStore.swift
//  ArchiveLib
//
//  Created by Julian Kahnert on 20.11.18.
//

import ArchiverModels
import ArchiverStore
import Foundation
import FoundationModels
import OSLog
import Shared

@available(iOS 26, macOS 26, *)
public actor ContentExtractorStore: Log {
    private static let maxTotalPromptLength = 3500

    private static var locale: Locale {
        Locale.current.region == "DE" ? Locale(identifier: "de_DE") : Locale.current
    }

    private static let options = GenerationOptions(
        sampling: .greedy,
        temperature: 0.0,
        maximumResponseTokens: 512
    )

    private var useCache = true
    private let cache = ContentExtractorCache()

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
    /// - Returns: Extracted specification and tags, or nil if unavailable
    public func extract(from text: String, customPrompt: String? = nil, with documents: [Document], documentId: Document.ID? = nil) async throws -> Info? {
        guard Self.getAvailability().isUsable else { return nil }

        // Check cache if document ID is provided
        if let documentId,
           useCache,
           let cachedEntry = await cache.getCachedResult(for: documentId) {
            Logger.contentExtractor.info("Using cached result for document ID: \(documentId)")
            return Info(specification: cachedEntry.specification, tags: cachedEntry.tags)
        }

        let session = Self.createSession(with: documents)

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

        let info = Info(specification: response.content.description.trimmingCharacters(in: .whitespacesAndNewlines),
                        tags: response.content.tags.prefix(10).map { $0.slugified(withSeparator: "") }
        )

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

    /// Update cache enabled state
    public func setCacheEnabled(_ enabled: Bool) async {
        useCache = enabled
    }

    /// Prune cache entries that don't have matching documents
    /// - Parameter validIds: Set of valid document IDs to keep in cache
    private func pruneCache(keepingOnly validIds: Set<Document.ID>) async {
        await cache.pruneCache(keepingOnly: validIds)
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
            let documentId = document.id

            // Skip if already cached
            if await cache.getCachedResult(for: documentId) != nil {
                continue
            }

            // Extract text and process (cache will be saved inside extract())
            guard let text = await textExtractor(document.url) else {
                continue
            }

            do {
                _ = try await extract(from: text,
                                     customPrompt: customPrompt,
                                     with: documents,
                                     documentId: documentId)
                newCachesCreated += 1
                Logger.contentExtractor.debug("Background cache entry created for document ID: \(documentId)")
            } catch {
                Logger.contentExtractor.error("Failed to create cache entry in background for document ID \(documentId): \(error)")
            }
        }

        // Prune cache entries for documents that no longer exist in untagged folder
        let untaggedIds = Set(untaggedDocuments.map(\.id))
        await cache.pruneCache(keepingOnly: untaggedIds)

        Logger.contentExtractor.info("Background cache processing completed: \(newCachesCreated) new caches created")

        return newCachesCreated
    }

    // MARK: - internal helper functions

    private static func createSession(with documents: [Document]) -> LanguageModelSession {
        let docStats = Self.getDocumentStats(minTagCount: 3, maxSpecifications: 20, with: documents)
        return LanguageModelSession(
            model: .default,
            tools: [],
            instructions: Instructions {

            // Task description
            """
            Your task is to archive documents by analyzing their content and generating appropriate descriptions and tags.
            If the document content does not contain enough information to create good tags/description, you MUST NOT hallucinate them - just return empty values.
            """

            // Document tags:
            """
            Tags MUST ALWAYS use existing tags from the system whenever applicable.
            Prefer frequently used tags to maintain consistency: \(docStats.tagCounts.prefix(500))
            If no suitable existing tags are found, create new appropriate tags.
            """

            // Document description:
            """
            The description should provide a concise summary of the document's content (5-10 words maximum).
            You MUST ALWAYS use the user's locale: \(Self.locale.identifier).
            You MUST ALWAYS model your new description after the examples, adapting the style and format to match the current document's content.
            Only use the current document content. DO NOT hallucinate.
            Example descriptions: \(docStats.specifications.prefix(500))
            """
            })
    }

    private struct DocStats {
        let tagCounts: String
        let specifications: String
    }

    private static func getDocumentStats(minTagCount: Int, maxSpecifications: Int, with documents: [Document]) -> DocStats {
        let tagCounts = Dictionary(grouping: documents.flatMap(\.tags)) {
            $0
        }
            .map { (name: $0, count: $1.count) }
            .filter { $0.count >= minTagCount }

        let formattedTagCounts = tagCounts
            .prefix(30)
            .map {
                "'\($0.0)': \($0.1)"
            }
        let tagCountsString = """
        'tagName': count
        \(formattedTagCounts)
        """

        let specificationsString = documents.sorted { $0.date > $1.date }
            .prefix(maxSpecifications)
            .map(\.specification)
            .joined(separator: "\n")

        return DocStats(tagCounts: tagCountsString,
                        specifications: specificationsString)
    }
}

@available(iOS 26.0, macOS 26.0, *)
extension ContentExtractorStore {
    @Generable
    struct DocumentInformation {
        @Guide(description: "short document description")
        var description: String

        @Guide(description: "document tags; lowercase; no symbols", .maximumCount(10))
        var tags: [String]
    }

    public struct Info: Sendable, Equatable {
        public let specification: String
        public let tags: [String]
    }
}

// #if canImport(FoundationModels)
// import Playgrounds
//
// @available(macOS 26.0, *)
// extension Transcript.Entry {
//    var toolCallCount: Int {
//        switch self {
//        case .toolCalls(let calls):
//            return calls.count
//        default:
//            return 0
//        }
//    }
// }
//
////    let text = "Bill of a blue hoddie from tom tailor"
// let text = """
//    TOM TAILOR
//    TOM TAILOR Retail GmbH
//    Garstedter Weg 14
//    22453 Hamburg
//    öffnungszeiten: Mo-Sa 9:30-20 Uhr
//    1 Jeans uni long Slim Aedan
//    62049720912 1052 31/34
//    4057655718688 1 × 49,99
//    Nachlassbetrag : 10,00EUR
//    49,99
//    10,00
//    39.99
//    Barometer
//    Bonsumme
//    Bonsumme (netto)
//    39,99
//    33,61
//    enthaltene MWST 19% 6,38
//    gegeben : Bar
//    Rückgeld:
//    40.00
//    0,01
//    Vielen Dank für Ihren Einkauf!
//    Es bediente Sie:
//    Ömer G.
//    Bon: 79535 05.01.17 13:45:30
//    Filiale: RT100089
//    Kasse: 01
//    Store Oldenburg Denim
//    Schlosshöfe
//    26122 01 denburg
//    Tel
//    USt-IdNr: DE 252291581
//    TOM TAILOR COLLECTORS CLUB
//    Mitglied werden und Vorteile genießen!
//    Rund um die Uhr einkaufen im
//    E-Shop unter TOM-TAILOR. DE
//    """
//
// #Playground {
//
//    guard #available(macOS 26.0, *) else { return }
//    
//    let store = ContentExtractorStore()
//    await store.prewarm()
//    
//    let response = try await store.extract(from: text)
//
//
//     let toolCallCount = store.session.transcript.map(\.toolCallCount).reduce(0, +)
//
////    for item in store.session.transcript {
////        switch item {
////        case .toolCalls(let calls):
////            print(calls)
////            
////        default:
////            break
////        }
////    }
//    print("Total tool call entries: \(toolCallCount)")
//    
//    print(response)
// }
// #endif
