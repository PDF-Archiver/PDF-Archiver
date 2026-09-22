//
//  Log.swift
//  
//
//  Created by Julian Kahnert on 20.10.20.
//

import Foundation
import OSLog

public protocol Log {
    var log: Logger { get }
}

public extension Log {
    nonisolated static var log: Logger {
        Logger(subsystem: Logger.subsystem, category: String(describing: self))
    }
    nonisolated var log: Logger {
        Self.log
    }
}

nonisolated public extension Logger {
    fileprivate static let subsystem = Bundle.main.bundleIdentifier ?? "de.JulianKahnert.PDFArchiveViewer"

#if DEBUG
    static let debugging = Logger(subsystem: subsystem, category: "debugging")
#endif

    static let app = Logger(subsystem: subsystem, category: "app")
    static let archiveIndexer = Logger(subsystem: subsystem, category: "archive-indexer")
    static let archiveStore = Logger(subsystem: subsystem, category: "archive-store")
    static let backgroundTask = Logger(subsystem: subsystem, category: "background-task")
    static let contentExtractor = Logger(subsystem: subsystem, category: "content-extractor")
    static let documentDetails = Logger(subsystem: subsystem, category: "document-details")
    static let documentProcessing = Logger(subsystem: subsystem, category: "document-processing")
    static let documentProcessor = Logger(subsystem: subsystem, category: "document-processor")
    static let ocrProcessing = Logger(subsystem: subsystem, category: "ocr-processing")
    static let inAppPurchase = Logger(subsystem: subsystem, category: "in-app-purchase")
    static let navigationModel = Logger(subsystem: subsystem, category: "navigation-model")
    static let newDocument = Logger(subsystem: subsystem, category: "new-document")
    static let notificationCenter = Logger(subsystem: subsystem, category: "notification-center")
    static let pdfDropHandler = Logger(subsystem: subsystem, category: "pdf-drop-handler")
    static let settings = Logger(subsystem: subsystem, category: "settings")
    static let taggingView = Logger(subsystem: subsystem, category: "tagging-view")

    nonisolated func errorAndAssert(_ message: String) {
        assertionFailure(message)
        error("\(message)")
    }

    // The composed message is public so it survives into the diagnostics report. Everything that
    // reaches a log call has to be redacted at the call site - see LogRedact.
    nonisolated func trace(_ message: String,
                           metadata: @autoclosure () -> [String: String],
                           file: StaticString = #file,
                           function: StaticString = #function,
                           line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        trace("\(tmp, privacy: .public)")
    }

    nonisolated func info(_ message: String,
                          metadata: @autoclosure () -> [String: String],
                          file: StaticString = #file,
                          function: StaticString = #function,
                          line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        info("\(tmp, privacy: .public)")
    }

    nonisolated func debug(_ message: String,
                           metadata: @autoclosure () -> [String: String],
                           file: StaticString = #file,
                           function: StaticString = #function,
                           line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        debug("\(tmp, privacy: .public)")
    }

    /// `notice` and above are the levels that persist to disk, so a sysdiagnose collected without a
    /// debugger attached still carries these - see the `debug`/`info` overloads above for what stays
    /// in-memory only.
    nonisolated func notice(_ message: String,
                            metadata: @autoclosure () -> [String: String],
                            file: StaticString = #file,
                            function: StaticString = #function,
                            line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        notice("\(tmp, privacy: .public)")
    }

    nonisolated func error(_ message: String,
                           metadata: @autoclosure () -> [String: String]?,
                           file: StaticString = #file,
                           function: StaticString = #function,
                           line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        error("\(tmp, privacy: .public)")
    }

    nonisolated func errorAndAssert(_ message: String,
                                    metadata: @autoclosure () -> [String: String]? = nil,
                                    file: StaticString = #file,
                                    function: StaticString = #function,
                                    line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        error("\(tmp, privacy: .public)")
        assertionFailure(message, file: file, line: line)
    }

    nonisolated func criticalAndAssert(_ message: String,
                                       metadata: @autoclosure () -> [String: String]? = nil,
                                       file: StaticString = #file,
                                       function: StaticString = #function,
                                       line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        critical("\(tmp, privacy: .public)")
        assertionFailure(message, file: file, line: line)
    }

    nonisolated func faultAndAssert(_ message: String,
                                    metadata: @autoclosure () -> [String: String]? = nil,
                                    file: StaticString = #file,
                                    function: StaticString = #function,
                                    line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        fault("\(tmp, privacy: .public)")
        assertionFailure(message, file: file, line: line)
    }

    /// Not `private`: `LogTests` asserts the field order directly, since OSLog's own output is not
    /// otherwise observable from a test.
    func input2message(_ message: String,
                       metadata: [String: String]?,
                       file: StaticString,
                       function: StaticString,
                       line: UInt) -> String {
        let metadataText: String
        if let metadataRaw = metadata,
           !metadataRaw.isEmpty {

            // `Dictionary` has no stable order - sorted here, or the same call site would print its
            // fields in a different order on every launch.
            let text = metadataRaw.sorted { $0.key < $1.key }.reduce("") { partialResult, element in
                "\(partialResult), [\(element.key): \(element.value)]"
            }
            metadataText = " metadata: \(text),"
        } else {
            metadataText = ""
        }
        return "\(message) -\(metadataText) file: \(URL(fileURLWithPath: file.description).lastPathComponent) \(function):\(line)"
    }
}
