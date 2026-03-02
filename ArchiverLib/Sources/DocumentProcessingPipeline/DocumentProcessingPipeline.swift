//
//  DocumentProcessingPipeline.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.02.26.
//

import Foundation
import OSLog

/// Orchestrates sequential execution of document processing steps
public actor DocumentProcessingPipeline {

    /// Status update emitted per processed URL
    public struct StatusUpdate: Sendable {
        public let url: URL
        public let step: PipelineConfiguration.StepKind

        public init(url: URL, step: PipelineConfiguration.StepKind) {
            self.url = url
            self.step = step
        }
    }

    /// Final result from a pipeline run
    public struct Result: Sendable {
        public let stepResults: [StepResult]

        public init(stepResults: [StepResult]) {
            self.stepResults = stepResults
        }
    }

    /// Result from a single pipeline step
    public struct StepResult: Sendable {
        public let step: PipelineConfiguration.StepKind
        public let processedCount: Int

        public init(step: PipelineConfiguration.StepKind, processedCount: Int) {
            self.step = step
            self.processedCount = processedCount
        }
    }

    private let steps: [any PipelineStep]

    public init() {
        self.steps = [
            OCRProcessingStep(),
            AICacheProcessingStep()
        ]
    }

    /// Mode 1: Fire-and-forget with status stream
    public func process(_ config: PipelineConfiguration) -> AsyncStream<StatusUpdate> {
        AsyncStream { continuation in
            Task {
                _ = await runSteps(config: config) { update in
                    continuation.yield(update)
                }
                continuation.finish()
            }
        }
    }

    /// Mode 2: Await result
    public func processAndWait(_ config: PipelineConfiguration) async -> Result {
        await runSteps(config: config, onUpdate: nil)
    }

    // MARK: - Private

    private func runSteps(config: PipelineConfiguration, onUpdate: (@Sendable (StatusUpdate) -> Void)?) async -> Result {
        var stepResults: [StepResult] = []

        for step in steps {
            guard !Task.isCancelled else { break }
            guard config.steps.contains(step.kind) else {
                Logger.pipeline.info("Pipeline step '\(step.kind.rawValue)' not in config, skipping")
                continue
            }

            Logger.pipeline.info("Pipeline step '\(step.kind.rawValue)' starting")
            let count = await step.process(urls: config.urls, config: config) { url in
                onUpdate?(StatusUpdate(url: url, step: step.kind))
            }
            stepResults.append(StepResult(step: step.kind, processedCount: count))
            Logger.pipeline.info("Pipeline step '\(step.kind.rawValue)' completed: \(count) documents processed")
        }

        return Result(stepResults: stepResults)
    }
}
