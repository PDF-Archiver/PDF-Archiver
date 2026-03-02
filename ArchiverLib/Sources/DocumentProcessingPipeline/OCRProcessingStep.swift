//
//  OCRProcessingStep.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.02.26.
//

import Foundation

/// Pipeline step that delegates to ``PDFOCRProcessor`` for each URL.
struct OCRProcessingStep: PipelineStep, Sendable {
    let kind: PipelineConfiguration.StepKind = .ocr

    func process(urls: [URL], config: PipelineConfiguration, onProcessed: @Sendable (URL) -> Void) async -> Int {
        var processedCount = 0

        for url in urls {
            guard !Task.isCancelled else { break }

            if await PDFOCRProcessor.processOCR(url: url) {
                processedCount += 1
                onProcessed(url)
            }
        }

        return processedCount
    }
}
