//
//  OSLogReporterTests.swift
//  ArchiverLib
//

import Foundation
import OSLog
import Testing

@testable import ArchiverFeatures

@Suite("OSLogReporter")
struct OSLogReporterTests {
    private static func entry(_ level: OSLogEntryLog.Level, _ message: String, date: Date = Date()) -> OSLogReporter.Entry {
        OSLogReporter.Entry(date: date, level: level, category: "test", message: message)
    }

    @Test("drops .debug and .undefined, keeps .info through .fault")
    func filtersByLevel() {
        let entries = [
            Self.entry(.undefined, "undefined-message"),
            Self.entry(.debug, "debug-message"),
            Self.entry(.info, "info-message"),
            Self.entry(.notice, "notice-message"),
            Self.entry(.error, "error-message"),
            Self.entry(.fault, "fault-message")
        ]

        let text = OSLogReporter.makeLogText(from: entries)

        #expect(!text.contains("undefined-message"))
        #expect(!text.contains("debug-message"))
        #expect(text.contains("info-message"))
        #expect(text.contains("notice-message"))
        #expect(text.contains("error-message"))
        #expect(text.contains("fault-message"))
    }

    @Test("caps the number of kept entries at maxEntryCount, keeping the most recent")
    func capsEntryCount() {
        let base = Date()
        let overflow = 500
        let total = OSLogReporter.maxEntryCount + overflow
        let entries = (0..<total).map { index in
            Self.entry(.info, "entry-\(index)", date: base.addingTimeInterval(TimeInterval(index)))
        }

        let body = String(OSLogReporter.makeLogText(from: entries).dropFirst(OSLogReporter.header.count))
        let lines = body.split(separator: "\n", omittingEmptySubsequences: true)

        #expect(lines.count == OSLogReporter.maxEntryCount)
        #expect(!lines.contains { $0.hasSuffix("entry-\(overflow - 1)") })
        #expect(lines.contains { $0.hasSuffix("entry-\(overflow)") })
        #expect(lines.contains { $0.hasSuffix("entry-\(total - 1)") })
    }

    @Test("caps the total size at maxByteCount, keeping the most recent lines")
    func capsByteSize() {
        let base = Date()
        let bigMessage = String(repeating: "x", count: 1000)
        let entries = (0..<1000).map { index in
            Self.entry(.info, "\(bigMessage)-\(index)", date: base.addingTimeInterval(TimeInterval(index)))
        }

        let body = String(OSLogReporter.makeLogText(from: entries).dropFirst(OSLogReporter.header.count))

        #expect(body.utf8.count <= OSLogReporter.maxByteCount)
        #expect(body.contains("-999"))
        #expect(!body.contains("-0\n"))
    }
}
