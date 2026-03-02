//
//  DocumentProcessingPipelineDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.02.26.
//

import ComposableArchitecture
import DocumentProcessingPipeline
import Foundation

@DependencyClient
struct DocumentProcessingPipelineDependency: Sendable {
    var process: @Sendable (PipelineConfiguration) async -> AsyncStream<DocumentProcessingPipeline.StatusUpdate> = { _ in
        AsyncStream { $0.finish() }
    }
    var processAndWait: @Sendable (PipelineConfiguration) async -> DocumentProcessingPipeline.Result = { _ in
        .init(stepResults: [])
    }
}

extension DocumentProcessingPipelineDependency: TestDependencyKey {
    static let previewValue = Self()
    static let testValue = Self()
}

extension DocumentProcessingPipelineDependency: DependencyKey {
    static let liveValue: Self = {
        let pipeline = DocumentProcessingPipeline()
        return Self(
            process: { config in
                await pipeline.process(config)
            },
            processAndWait: { config in
                await pipeline.processAndWait(config)
            }
        )
    }()
}

extension DependencyValues {
    var documentProcessingPipeline: DocumentProcessingPipelineDependency {
        get { self[DocumentProcessingPipelineDependency.self] }
        set { self[DocumentProcessingPipelineDependency.self] = newValue }
    }
}
