//
//  AICacheProcessingStep.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.02.26.
//

import ArchiverModels
import ContentExtractorStore
import Dependencies
import Foundation
import OSLog
import Shared
import Sharing

/// Delegates to ContentExtractorStore to create Apple Intelligence cache entries for untagged documents
@available(iOS 26, macOS 26, *)
public struct AICacheProcessingStep: DocumentProcessingStep, Sendable {
    public let name = "AI Cache"

    @SharedReader(.appleIntelligenceEnabled) private var aiEnabled: Bool
    @SharedReader(.appleIntelligenceCacheEnabled) private var cacheEnabled: Bool

    public var isEnabled: Bool { aiEnabled && cacheEnabled }

    @Dependency(\.contentExtractorStore) var contentExtractorStore

    public init() {}

    public func process(context: DocumentProcessingContext) async -> DocumentProcessingStepResult {
        let count = await contentExtractorStore.processUntaggedDocumentsInBackground(
            context.documents,
            context.textExtractor,
            context.customPrompt
        )
        return DocumentProcessingStepResult(stepName: name, documentsProcessed: count)
    }
}
