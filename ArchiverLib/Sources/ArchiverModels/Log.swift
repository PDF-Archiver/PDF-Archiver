//
//  Log.swift
//
//
//  Created by Julian Kahnert on 20.10.20.
//

import Foundation
import Logging

public protocol Log {
    var log: Logger { get }
}

public extension Log {
    nonisolated static var log: Logger {
        Logger(label: String(describing: self))
    }
    nonisolated var log: Logger {
        Self.log
    }
}

// The labels are the OSLog categories `OSLogHandler` logs under.
nonisolated public extension Logger {
    static let app = Logger(label: "app")
    static let archiveIndexer = Logger(label: "archive-indexer")
    static let archiveStore = Logger(label: "archive-store")
    static let backgroundTask = Logger(label: "background-task")
    static let contentExtractor = Logger(label: "content-extractor")
    static let documentDetails = Logger(label: "document-details")
    static let documentProcessor = Logger(label: "document-processor")
    static let ocrProcessing = Logger(label: "ocr-processing")
    static let inAppPurchase = Logger(label: "in-app-purchase")
    static let notificationCenter = Logger(label: "notification-center")
    static let pdfDropHandler = Logger(label: "pdf-drop-handler")
    static let settings = Logger(label: "settings")

    // `file` is a `StaticString` so the assertion points at the caller rather than this file.
    func errorAndAssert(_ message: Logger.Message,
                        metadata: @autoclosure () -> Logger.Metadata? = nil,
                        file: StaticString = #fileID,
                        function: String = #function,
                        line: UInt = #line) {
        error(message, metadata: metadata(), file: "\(file)", function: function, line: line)
        assertionFailure(message.description, file: file, line: line)
    }

    func criticalAndAssert(_ message: Logger.Message,
                           metadata: @autoclosure () -> Logger.Metadata? = nil,
                           file: StaticString = #fileID,
                           function: String = #function,
                           line: UInt = #line) {
        critical(message, metadata: metadata(), file: "\(file)", function: function, line: line)
        assertionFailure(message.description, file: file, line: line)
    }

    /// OSLog's name for `critical` - both reach OSLog as a fault.
    func faultAndAssert(_ message: Logger.Message,
                        metadata: @autoclosure () -> Logger.Metadata? = nil,
                        file: StaticString = #fileID,
                        function: String = #function,
                        line: UInt = #line) {
        criticalAndAssert(message, metadata: metadata(), file: file, function: function, line: line)
    }
}

public extension Duration {
    /// Whole milliseconds, the unit of every `durationMs` log field.
    var inMilliseconds: Int {
        Int(components.seconds * 1000 + components.attoseconds / 1_000_000_000_000_000)
    }
}
