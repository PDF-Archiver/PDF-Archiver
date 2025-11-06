//
//  ContentExtractorStoreDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.25.
//

import ArchiverModels
import ArchiverStore
import ComposableArchitecture
import Foundation
import OSLog
import Shared

@DependencyClient
public struct ContentExtractorStoreDependency: Sendable {
    @Dependency(\.archiveStore) var archiveStore

    /// Input for document information extraction
    public struct DocInfoInput: Sendable {
        /// Existing documents for context (tags, specifications)
        public let currentDocuments: [Document]
        /// The document text content to analyze
        public let text: String
        /// Optional custom prompt to guide the extraction
        public let customPrompt: String?
        /// Optional document ID for caching results
        public let documentId: Document.ID?

        public init(currentDocuments: [Document], text: String, customPrompt: String?, documentId: Document.ID? = nil) {
            self.currentDocuments = currentDocuments
            self.text = text
            self.customPrompt = customPrompt
            self.documentId = documentId
        }
    }

    /// Output from document information extraction
    public struct DocInfo: Sendable {
        /// Extracted document specification/description
        public let specification: String
        /// Extracted document tags
        public let tags: Set<String>
    }

    @available(iOS 26, macOS 26, *)
    private static let contentExtractorStore = ContentExtractorStore()

    /// Check if Apple Intelligence is available on this device
    /// - Returns: Availability status for Apple Intelligence
    public var isAvailable: @Sendable () async -> AppleIntelligenceAvailability = { .operatingSystemNotCompatible }

    /// Extract document information using Apple Intelligence
    /// - Parameter input: Input containing text, documents context, and optional custom prompt
    /// - Returns: Extracted specification and tags, or nil if unavailable
    public var getDocumentInformation: @Sendable (DocInfoInput) async -> DocInfo?

    /// Clear all cache entries
    public var clearCache: @Sendable () async -> Void = {}

    /// Get the number of cached entries
    /// - Returns: Count of cache entries
    public var getCacheCount: @Sendable () async -> Int = { 0 }

    /// Enable or disable the cache
    /// - Parameter enabled: Whether cache should be enabled
    public var setCacheEnabled: @Sendable (Bool) async -> Void = { _ in }

    /// Process untagged documents in background to create cache entries
    /// - Parameters:
    ///   - documents: All documents to process
    ///   - textExtractor: Closure to extract text from document URL
    ///   - customPrompt: Optional custom prompt for extraction
    public var processUntaggedDocumentsInBackground: @Sendable ([Document], @Sendable (URL) async -> String?, String?) async -> Void = { _, _, _ in }
}

extension ContentExtractorStoreDependency: TestDependencyKey {
    public static let previewValue = Self(
        isAvailable: { .available },
        getDocumentInformation: { _ in nil },
        clearCache: {},
        getCacheCount: { 0 },
        setCacheEnabled: { _ in },
        processUntaggedDocumentsInBackground: { _, _, _ in }
    )

    public static let testValue = Self()
}

extension ContentExtractorStoreDependency: DependencyKey {
    public static let liveValue = ContentExtractorStoreDependency(
        isAvailable: {
            guard #available(iOS 26.0, macOS 26.0, *) else {
                return .operatingSystemNotCompatible
            }

            return ContentExtractorStore.getAvailability()
        },
        getDocumentInformation: { input in
            guard #available(iOS 26.0, macOS 26.0, *) else { return nil }
            do {
                guard let result = try await contentExtractorStore.extract(from: input.text,
                                                                           customPrompt: input.customPrompt,
                                                                           with: input.currentDocuments,
                                                                           documentId: input.documentId) else { return nil }

                return DocInfo(specification: result.specification,
                               tags: Set(result.tags))
            } catch {
                Logger.contentExtractor.errorAndAssert("An error occurred while extracting document content", metadata: ["error": "\(error)"])
                return nil
            }
        },
        clearCache: {
            guard #available(iOS 26.0, macOS 26.0, *) else { return }
            await contentExtractorStore.clearCache()
        },
        getCacheCount: {
            guard #available(iOS 26.0, macOS 26.0, *) else { return 0 }
            return await contentExtractorStore.getCacheCount()
        },
        setCacheEnabled: { enabled in
            guard #available(iOS 26.0, macOS 26.0, *) else { return }
            await contentExtractorStore.setCacheEnabled(enabled)
        },
        processUntaggedDocumentsInBackground: { documents, textExtractor, customPrompt in
            guard #available(iOS 26.0, macOS 26.0, *) else { return }
            await contentExtractorStore.processUntaggedDocumentsInBackground(documents: documents,
                                                                             textExtractor: textExtractor,
                                                                             customPrompt: customPrompt)
        }
    )
}

public extension DependencyValues {
    var contentExtractorStore: ContentExtractorStoreDependency {
        get { self[ContentExtractorStoreDependency.self] }
        set { self[ContentExtractorStoreDependency.self] = newValue }
    }
}
