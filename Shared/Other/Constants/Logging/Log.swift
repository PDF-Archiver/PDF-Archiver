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
    static var log: Logger {
        Logger(subsystem: Logger.subsystem, category: String(describing: self))
    }
    var log: Logger {
        Self.log
    }
}

extension Logger {
    fileprivate static let subsystem = Bundle.main.bundleIdentifier!

    #if DEBUG
    static let debugging = Logger(subsystem: subsystem, category: "debugging")
    #endif
    
    static let archiveStore = Logger(subsystem: subsystem, category: "archive-store")
    static let inAppPurchase = Logger(subsystem: subsystem, category: "in-app-purchase")
    static let newDocument = Logger(subsystem: subsystem, category: "new-document")
    static let pdfDropHandler = Logger(subsystem: subsystem, category: "pdf-drop-handler")
    static let documentProcessing = Logger(subsystem: subsystem, category: "document-processing")

    func errorAndAssert(_ message: String) {
        assertionFailure(message)
        error("\(message)")
    }

    func assert(_ condition: Bool, _ message: String) {
        guard !condition else { return }
        assertionFailure(message)
        error("\(message)")
    }

    func trace(_ message: String,
               metadata: @autoclosure () -> [String: String],
               file: StaticString = #file,
               function: StaticString = #function,
               line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        trace("\(tmp)")
    }
    
    func info(_ message: String,
               metadata: @autoclosure () -> [String: String],
               file: StaticString = #file,
               function: StaticString = #function,
               line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        info("\(tmp)")
    }
    
    func debug(_ message: String,
               metadata: @autoclosure () -> [String: String],
               file: StaticString = #file,
               function: StaticString = #function,
               line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        debug("\(tmp)")
    }
    
    func error(_ message: String,
               metadata: @autoclosure () -> [String: String]?,
               file: StaticString = #file,
               function: StaticString = #function,
               line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        error("\(tmp)")
    }
    
    func errorAndAssert(_ message: String,
                        metadata: @autoclosure () -> [String: String]? = nil,
                        file: StaticString = #file,
                        function: StaticString = #function,
                        line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        error("\(tmp)")
        assertionFailure(message, file: file, line: line)
    }

    func criticalAndAssert(_ message: String,
                           metadata: @autoclosure () -> [String: String]? = nil,
                           file: StaticString = #file,
                           function: StaticString = #function,
                           line: UInt = #line) {
        let tmp = input2message(message, metadata: metadata(), file: file, function: function, line: line)
        critical("\(tmp)")
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
