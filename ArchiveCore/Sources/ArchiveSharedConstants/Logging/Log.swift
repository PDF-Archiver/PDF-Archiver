//
//  Log.swift
//  
//
//  Created by Julian Kahnert on 20.10.20.
//

import Logging

public protocol Log {
    var log: Logger { get }
}

public extension Log {
    static var log: Logger {
        Logger(label: String(describing: self))
    }
    var log: Logger {
        Self.log
    }
}

public extension Logger {
    func errorAndAssert(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      source: @autoclosure () -> String? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.error(message(), metadata: metadata(), file: file, function: function, line: line)
        assertionFailure(message().description)
    }

    func criticalAndAssert(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      source: @autoclosure () -> String? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.critical(message(), metadata: metadata(), file: file, function: function, line: line)
        assertionFailure(message().description)
    }
}
