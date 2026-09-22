//
//  LogTests.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 21.09.26.
//

import Foundation
import OSLog
import Testing

@testable import ArchiverModels

@Suite
struct LogTests {
    /// `metadata` is a `Dictionary`, so without sorting, a multi-field log line would print its
    /// fields in a different, undefined order on every launch.
    @Test
    func metadataFieldsAreSortedByKey() {
        let message = Logger.app.input2message(
            "test",
            metadata: ["zebra": "1", "alpha": "2", "mid": "3"],
            file: "File.swift",
            function: "function()",
            line: 42)

        let alphaRange = message.range(of: "[alpha: 2]")
        let midRange = message.range(of: "[mid: 3]")
        let zebraRange = message.range(of: "[zebra: 1]")

        #expect(alphaRange != nil && midRange != nil && zebraRange != nil)
        if let alphaRange, let midRange, let zebraRange {
            #expect(alphaRange.lowerBound < midRange.lowerBound)
            #expect(midRange.lowerBound < zebraRange.lowerBound)
        }
    }
}
