//
//  main.swift
//  ocr-tool
//
//  CLI tool that adds an invisible text layer to image-only PDFs.
//  Uses the same OCR logic as the PDF Archiver app.
//
//  Usage: swift run ocr-tool <path-to-pdf>
//  Build: swift build --product ocr-tool
//

import DocumentProcessingPipeline
import Foundation

guard CommandLine.arguments.count == 2 else {
    print("Usage: ocr-tool <path-to-pdf>")
    exit(1)
}

let path = CommandLine.arguments[1]
let url = URL(fileURLWithPath: path)

guard FileManager.default.fileExists(atPath: path) else {
    print("Error: File not found: \(path)")
    exit(1)
}

print("Processing \(url.lastPathComponent)...")

let semaphore = DispatchSemaphore(value: 0)

Task {
    let success = await PDFOCRProcessor.processOCR(url: url) { pageIndex, pageCount, regions in
        print("  Page \(pageIndex + 1)/\(pageCount): \(regions) text regions added")
    }

    if success {
        print("Done: OCR text layer added to \(path)")
    } else {
        print("No changes: PDF already has text or no text was recognized.")
    }

    semaphore.signal()
}

semaphore.wait()
