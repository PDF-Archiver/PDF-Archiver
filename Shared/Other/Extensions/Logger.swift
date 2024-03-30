//
//  Logger.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.03.24.
//

import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier!

    #if DEBUG
    static let debugging = Logger(subsystem: subsystem, category: "DEBUG")
    #endif
    
    static let archiveStore = Logger(subsystem: subsystem, category: "archive-store")
    static let newDocument = Logger(subsystem: subsystem, category: "new-document")

    func errorAndAssert(_ message: String) {
        assertionFailure(message)
        error("\(message)")
    }

    func assert(_ condition: Bool, _ message: String) {
        guard !condition else { return }
        assertionFailure(message)
        error("\(message)")
    }
}
