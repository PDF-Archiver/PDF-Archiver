//
//  AICacheProcessingStep.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.02.26.
//

import ArchiverModels
import ArchiverStore
import ContentExtractorStore
import Dependencies
import Foundation
import OSLog
import Shared
import Sharing

/// Pre-caches AI-generated descriptions and tags for documents.
/// Uses archiveStore and contentExtractorStore dependencies directly.
/// Expects only untagged document URLs — filtering must happen before calling this step.
struct AICacheProcessingStep: PipelineStep, Sendable {
    let kind: PipelineConfiguration.StepKind = .aiCache

    @Dependency(\.archiveStore) var archiveStore
    @Dependency(\.contentExtractorStore) var contentExtractorStore
    @SharedReader(.appleIntelligenceCustomPrompt) var customPrompt: String?

    func process(urls: [URL], config: PipelineConfiguration, onProcessed: @Sendable (URL) -> Void) async -> Int {
        let documents: [Document]
        do {
            documents = try await archiveStore.getDocuments()
        } catch {
            Logger.aiCacheStep.error("AI Cache step failed to fetch documents: \(error)")
            return 0
        }

        let documentsByURL = Dictionary(uniqueKeysWithValues: documents.compactMap { doc in
            (doc.url, doc)
        })

        // Documents are processed sequentially because Apple Intelligence
        // does not support concurrent requests (returns a concurrentRequests error).
        var processedCount = 0
        for url in urls {
            guard let doc = documentsByURL[url] else { continue }
            guard let text = PDFTextExtractor.extractText(from: url) else { continue }
            let result = await contentExtractorStore.getDocumentInformation(
                .init(currentDocuments: documents, text: text, customPrompt: customPrompt, documentId: doc.id)
            )
            if result != nil {
                processedCount += 1
                onProcessed(url)
            }
        }

        // Prune cache entries for documents that no longer exist
        let validIds = Set(urls.compactMap { documentsByURL[$0]?.id })
        await contentExtractorStore.pruneCache(validIds)

        return processedCount
    }
}
