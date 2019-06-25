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

    static func info(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        guard let event = Event(.info, msg: message, file: file, line: line, function: function) else { return }
        shared?.send(event: event, completion: nil)
    }
}

extension Event {
    fileprivate convenience init?(_ level: SentrySeverity, msg message: String, file: String, line: Int, function: String) {
        self.init(level: level)
        self.message = message
        self.extra = [
            "file": file,
            "line": line,
            "function": function
        ]
    }
}
