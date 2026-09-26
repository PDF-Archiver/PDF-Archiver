//
//  LogTests.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 21.09.26.
//

import Foundation
import Logging
import Testing

@testable import ArchiverModels

@Suite
struct LogTests {
    /// `metadata` is a `Dictionary`, so without sorting, a multi-field log line would print its
    /// fields in a different, undefined order on every launch.
    @Test
    func metadataFieldsAreSortedByKey() {
        let message = OSLogHandler.composedMessage(
            "test",
            metadata: ["zebra": "1", "alpha": "2", "mid": "3"],
            file: "ArchiverModels/File.swift",
            function: "function()",
            line: 42)

        #expect(message == "test - metadata: , [alpha: 2], [mid: 3], [zebra: 1], file: File.swift function():42")
    }
}
