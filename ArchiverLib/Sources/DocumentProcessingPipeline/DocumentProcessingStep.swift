//
//  DocumentProcessingStep.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.02.26.
//

import ArchiverModels
import Foundation

/// Context passed to each pipeline step
public struct DocumentProcessingContext: Sendable {
    public let documents: [Document]
    public let textExtractor: @Sendable (URL) async -> String?
    public let customPrompt: String?

    public init(
        documents: [Document],
        textExtractor: @escaping @Sendable (URL) async -> String?,
        customPrompt: String?
    ) {
        self.documents = documents
        self.textExtractor = textExtractor
        self.customPrompt = customPrompt
    }
}

/// Result from a single pipeline step
public struct DocumentProcessingStepResult: Sendable {
    public let stepName: String
    public let documentsProcessed: Int

    public init(stepName: String, documentsProcessed: Int) {
        self.stepName = stepName
        self.documentsProcessed = documentsProcessed
    }
}

/// Protocol for background document processing steps
public protocol DocumentProcessingStep: Sendable {
    /// Human-readable name for logging
    var name: String { get }

    /// Whether this step is currently enabled (checked at runtime)
    var isEnabled: Bool { get }

    /// Process documents and return a result with the count of documents processed
    func process(context: DocumentProcessingContext) async -> DocumentProcessingStepResult
}
