//
//  ArchiveLogFileReporterTests.swift
//  ArchiverLib
//

import Foundation
import Testing

@testable import ArchiverFeatures

struct ArchiveLogFileReporterTests {
    private let directory: URL

    init() throws {
        directory = URL.temporaryDirectory.appendingPathComponent("ArchiveLogFileReporterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    @Test
    func theFilesAppearOldestFirstUnderTheirNames() throws {
        try write("2026-09-27_08-00-00_BBBBBB.jsonl", "second")
        try write("2026-09-26_21-00-00_AAAAAA.jsonl", "first")
        try write("2026-09-26_21-00-00_AAAAAA_2.jsonl", "first continued")

        let text = ArchiveLogFileReporter.makeLogText(in: directory, maxByteCount: 10_000)

        let first = try #require(text.range(of: "== 2026-09-26_21-00-00_AAAAAA.jsonl =="))
        let continued = try #require(text.range(of: "== 2026-09-26_21-00-00_AAAAAA_2.jsonl =="))
        let second = try #require(text.range(of: "== 2026-09-27_08-00-00_BBBBBB.jsonl =="))
        #expect(first.lowerBound < continued.lowerBound)
        #expect(continued.lowerBound < second.lowerBound)
        #expect(text.contains("first continued"))
    }

    /// The newest lines are the ones a support request is about, so the oldest give way.
    @Test
    func theNewestLinesSurviveTheCap() throws {
        try write("2026-09-26_21-00-00_AAAAAA.jsonl", String(repeating: "old line\n", count: 100))
        try write("2026-09-27_08-00-00_BBBBBB.jsonl", "new line")

        let text = ArchiveLogFileReporter.makeLogText(in: directory, maxByteCount: 200)

        #expect(text.contains("new line"))
        #expect(text.utf8.count < 400)
    }

    @Test
    func otherFilesAreIgnored() throws {
        try write("2026-09-27_08-00-00_BBBBBB.jsonl", "log line")
        try write("notes.txt", "not a log")

        let text = ArchiveLogFileReporter.makeLogText(in: directory, maxByteCount: 10_000)

        #expect(!text.contains("not a log"))
    }

    @Test
    func aMissingFolderIsExplainedInsteadOfFailing() {
        let missing = directory.appendingPathComponent("missing", isDirectory: true)

        let text = ArchiveLogFileReporter.makeLogText(in: missing, maxByteCount: 10_000)

        #expect(text == ArchiveLogFileReporter.noLogsText)
    }

    private func write(_ name: String, _ content: String) throws {
        try Data(content.utf8).write(to: directory.appendingPathComponent(name))
    }
}
