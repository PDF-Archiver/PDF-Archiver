//
//  PipelineTypes.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.02.26.
//

import Foundation

/// Configuration for a pipeline run
public struct PipelineConfiguration: Sendable {
    /// PDF file URLs to process
    public let urls: [URL]

    /// Which steps to execute
    public let steps: Set<StepKind>

    public init(
        urls: [URL],
        steps: Set<StepKind>
    ) {
        self.urls = urls
        self.steps = steps
    }

    /// Available processing steps
    public enum StepKind: String, Sendable, Hashable, CaseIterable {
        case ocr
        case aiCache
    }
}

/// A single processing step that the ``DocumentProcessingPipeline`` executes.
///
/// Each step declares which ``PipelineConfiguration/StepKind`` it handles and
/// provides a ``process(urls:config:onProcessed:)`` method that performs the
/// actual work on a list of document URLs.
///
/// Conforming types must be `Sendable` because steps may be executed
/// concurrently by the pipeline.
protocol PipelineStep: Sendable {
    /// The kind of processing this step performs.
    ///
    /// The pipeline uses this value to decide whether the step should run
    /// for a given ``PipelineConfiguration``.
    var kind: PipelineConfiguration.StepKind { get }

    /// Process the given document URLs.
    ///
    /// - Parameters:
    ///   - urls: The document URLs to process.
    ///   - config: The pipeline configuration for the current run.
    ///   - onProcessed: A callback invoked once per successfully processed URL,
    ///     allowing the pipeline to emit progress updates.
    /// - Returns: The number of documents that were successfully processed.
    func process(urls: [URL], config: PipelineConfiguration, onProcessed: @Sendable (URL) -> Void) async -> Int
}
