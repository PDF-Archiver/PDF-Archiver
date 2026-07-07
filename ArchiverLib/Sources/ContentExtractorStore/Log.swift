//
//  Log.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.26.
//

import Foundation
import OSLog

nonisolated extension Logger {
    static let contentExtractor = Logger(subsystem: Bundle.main.bundleIdentifier ?? "de.JulianKahnert.PDFArchiveViewer", category: "content-extractor")
}
