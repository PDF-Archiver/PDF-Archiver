//
//  Log.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.26.
//

import Foundation
import OSLog

nonisolated extension Logger {
    fileprivate static let subsystem = Bundle.main.bundleIdentifier ?? "de.JulianKahnert.PDFArchiveViewer"

    static let dateParser = Logger(subsystem: subsystem, category: "date-parser")
}
