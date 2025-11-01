//
//  Log.swift
//  
//
//  Created by Julian Kahnert on 20.10.20.
//

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
    // swiftlint:disable:next force_unwrapping
    fileprivate static let subsystem = Bundle.main.bundleIdentifier!

#if DEBUG
    static let debugging = Logger(subsystem: subsystem, category: "debugging")
#endif

    static let app = Logger(subsystem: subsystem, category: "app")
    static let archiveStore = Logger(subsystem: subsystem, category: "archive-store")
    static let backgroundTask = Logger(subsystem: subsystem, category: "background-task")
    static let contentExtractor = Logger(subsystem: subsystem, category: "content-extractor")
    static let documentProcessing = Logger(subsystem: subsystem, category: "document-processing")
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

    nonisolated func trace(_ message: String,
                           metadata: @autoclosure () -> [String: String],
                           file: StaticString = #file,
                           function: StaticString = #function,
                           line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        trace("\(tmp)")
    }

    nonisolated func info(_ message: String,
                          metadata: @autoclosure () -> [String: String],
                          file: StaticString = #file,
                          function: StaticString = #function,
                          line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        info("\(tmp)")
    }

    nonisolated func debug(_ message: String,
                           metadata: @autoclosure () -> [String: String],
                           file: StaticString = #file,
                           function: StaticString = #function,
                           line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        debug("\(tmp)")
    }

    nonisolated func error(_ message: String,
                           metadata: @autoclosure () -> [String: String]?,
                           file: StaticString = #file,
                           function: StaticString = #function,
                           line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        error("\(tmp)")
    }

    nonisolated func errorAndAssert(_ message: String,
                                    metadata: @autoclosure () -> [String: String]? = nil,
                                    file: StaticString = #file,
                                    function: StaticString = #function,
                                    line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        error("\(tmp)")
        assertionFailure(message, file: file, line: line)
    }

    nonisolated func criticalAndAssert(_ message: String,
                                       metadata: @autoclosure () -> [String: String]? = nil,
                                       file: StaticString = #file,
                                       function: StaticString = #function,
                                       line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        critical("\(tmp)")
        assertionFailure(message, file: file, line: line)
    }

    nonisolated func faultAndAssert(_ message: String,
                                    metadata: @autoclosure () -> [String: String]? = nil,
                                    file: StaticString = #file,
                                    function: StaticString = #function,
                                    line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        fault("\(tmp)")
        assertionFailure(message, file: file, line: line)
    }

    private func input2message(_ message: String,
                               metadata: [String: String]?,
                               file: StaticString,
                               function: StaticString,
                               line: UInt) -> String {
        let metadataText: String
        if let metadataRaw = metadata,
           !metadataRaw.isEmpty {

            let text = metadataRaw.reduce("") { partialResult, element in
                "\(partialResult), [\(element.key): \(element.value)]"
            }
            metadataText = " metadata: \(text),"
        } else {
            metadataText = ""
        }
        return "\(message) -\(metadataText) file: \(URL(fileURLWithPath: file.description).lastPathComponent) \(function):\(line)"
    }
}
