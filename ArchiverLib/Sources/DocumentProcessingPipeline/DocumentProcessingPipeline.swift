//
//  DocumentProcessingPipeline.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.02.26.
//

import Foundation
import OSLog
import Shared

/// Orchestrates sequential execution of document processing steps
public actor DocumentProcessingPipeline {
    private let steps: [any DocumentProcessingStep]

    public init(steps: [any DocumentProcessingStep]) {
        self.steps = steps
    }

    /// Run all enabled steps sequentially
    public func run(context: DocumentProcessingContext) async -> [DocumentProcessingStepResult] {
        var results: [DocumentProcessingStepResult] = []

        for step in steps {
            guard !Task.isCancelled else { break }

            guard step.isEnabled else {
                Logger.processingPipeline.info("Pipeline step '\(step.name)' is disabled, skipping")
                continue
            }

            Logger.processingPipeline.info("Pipeline step '\(step.name)' starting")
            let result = await step.process(context: context)
            results.append(result)
            Logger.processingPipeline.info("Pipeline step '\(step.name)' completed: \(result.documentsProcessed) documents processed")
        }

        return results
    }
}
