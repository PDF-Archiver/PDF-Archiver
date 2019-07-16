//
//  Logger.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 25.06.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation
import Sentry

enum Log {

    private static let shared = Client.shared

    static func info(_ message: String, extra data: [String: Any] = [:], file: String = #file, line: Int = #line, function: String = #function) {
        guard Environment.get() != .develop,
            let event = Event(.info, msg: message, extra: data, file: file, line: line, function: function) else { return }
        shared?.send(event: event, completion: nil)
    }

    static func error(_ message: String, extra data: [String: Any] = [:], file: String = #file, line: Int = #line, function: String = #function) {
        guard Environment.get() != .develop,
            let event = Event(.error, msg: message, extra: data, file: file, line: line, function: function) else { return }
        shared?.send(event: event, completion: nil)
    }
}

extension Event {
    fileprivate convenience init?(_ level: SentrySeverity, msg message: String, extra: [String: Any], file: String, line: Int, function: String) {
        self.init(level: level)
        self.message = message
        self.extra = extra
        self.extra?["file"] = file
        self.extra?["line"] = line
        self.extra?["function"] = function
    }
}
