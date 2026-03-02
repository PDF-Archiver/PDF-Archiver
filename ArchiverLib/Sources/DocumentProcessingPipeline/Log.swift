//
//  Log.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 01.03.26.
//

import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "de.JulianKahnert.PDFArchiveViewer"

    static let pipeline = Logger(subsystem: subsystem, category: "processing-pipeline")
    static let ocrStep = Logger(subsystem: subsystem, category: "ocr-step")
    static let aiCacheStep = Logger(subsystem: subsystem, category: "ai-cache-step")
}
