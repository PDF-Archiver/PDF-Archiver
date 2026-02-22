//
//  DocumentProcessingPipelineDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.02.26.
//

import ArchiverModels
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DocumentProcessingPipelineDependency: Sendable {
    /// Run the full processing pipeline on documents
    /// - Parameter context: Processing context with documents, text extractor, and optional prompt
    /// - Returns: Results from each pipeline step
    public var run: @Sendable (DocumentProcessingContext) async -> [DocumentProcessingStepResult] = { _ in [] }

    /// Run OCR on a single document, bypassing the `ocrEnabled` setting.
    /// Returns `true` if a text layer was added.
    public var runOCROnDocument: @Sendable (Document) async -> Bool = { _ in false }
}

extension DocumentProcessingPipelineDependency: TestDependencyKey {
    public static let previewValue = Self(run: { _ in [] }, runOCROnDocument: { _ in false })
    public static let testValue = Self()
}

extension DocumentProcessingPipelineDependency: DependencyKey {
    public static let liveValue: Self = {
        // Build pipeline with steps in order: OCR first, then AI Cache
        let ocrStep = OCRProcessingStep()
        var steps: [any DocumentProcessingStep] = [ocrStep]

        if #available(iOS 26, macOS 26, *) {
            steps.append(AICacheProcessingStep())
        }

        let pipeline = DocumentProcessingPipeline(steps: steps)

        return Self(
            run: { context in
                await pipeline.run(context: context)
            },
            runOCROnDocument: { document in
                await ocrStep.performOCROnDocument(document)
            }
        )
    }()
}

public extension DependencyValues {
    var documentProcessingPipeline: DocumentProcessingPipelineDependency {
        get { self[DocumentProcessingPipelineDependency.self] }
        set { self[DocumentProcessingPipelineDependency.self] = newValue }
    }
}
