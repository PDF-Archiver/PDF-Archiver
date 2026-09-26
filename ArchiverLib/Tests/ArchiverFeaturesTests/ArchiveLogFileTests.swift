//
//  ArchiveLogFileTests.swift
//  ArchiverLib
//

import Foundation
import Logging
import Testing

@testable import ArchiverFeatures

struct ArchiveLogFileTests {
    private static let header = Data(#"{"header":"test"}"#.utf8)

    private let directory: URL

    init() throws {
        directory = URL.temporaryDirectory.appendingPathComponent("ArchiveLogFileTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    @Test
    func eachLogCallBecomesOneJSONObjectAfterTheSessionHeader() async throws {
        let file = ArchiveLogFile { [directory] in directory }
        await file.enable(header: Self.header)?.value
        let logger = Self.logger(writingTo: file)

        let loggedLine: UInt = #line + 1
        logger.notice("Something happened", metadata: ["count": "3"])

        let lines = try Self.fileLines(in: directory).flatMap(\.self)
        try #require(lines.count == 2)
        #expect(lines[0] == String(bytes: Self.header, encoding: .utf8))
        let entry = try JSONDecoder().decode(Entry.self, from: Data(lines[1].utf8))
        #expect(entry.msg == "Something happened")
        #expect(entry.meta == ["count": "3"])
        #expect(entry.lvl == "notice")
        #expect(entry.label == "test")
        #expect(entry.src == "ArchiveLogFileTests.swift:\(loggedLine) eachLogCallBecomesOneJSONObjectAfterTheSessionHeader()")
    }

    @Test
    func linesLoggedBeforeTheFolderResolvesAreWrittenInOrder() async throws {
        let (gate, open) = AsyncStream<Void>.makeStream()
        let file = ArchiveLogFile { [directory] in
            var iterator = gate.makeAsyncIterator()
            await iterator.next()
            return directory
        }
        let resolution = file.enable(header: Self.header)
        let logger = Self.logger(writingTo: file)

        logger.info("first")
        logger.info("second")
        logger.info("third")
        open.yield()
        await resolution?.value

        #expect(try Self.messages(in: directory) == ["first", "second", "third"])
    }

    @Test
    func aFullFileContinuesInTheNextOne() async throws {
        let file = ArchiveLogFile(maximumFileSize: 600) { [directory] in directory }
        await file.enable(header: Self.header)?.value
        let logger = Self.logger(writingTo: file)

        for index in 0..<8 {
            logger.info("line", metadata: ["index": "\(index)"])
        }

        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        #expect(names.count > 1)
        #expect(names.dropFirst().first?.hasSuffix("_\(file.session)_2.jsonl") == true)
        for name in names {
            let size = try #require(try FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent(name).path)[.size] as? Int)
            #expect(size <= 600, "\(name) is \(size) bytes")
        }
        let indices = try Self.entries(in: directory).map { $0.meta["index"] }
        #expect(indices == (0..<8).map { "\($0)" })
    }

    @Test
    func theDeviceFolderNameCannotNestOrBreakAPath() {
        #expect(ArchiveLogFile.deviceFolderName(name: "Julian's Mac/Book: Pro", model: "Mac16,8") == "Julian's Mac-Book- Pro (Mac16,8)")
    }

    @Test
    func aDisabledFileWritesNothing() async throws {
        let file = ArchiveLogFile { [directory] in directory }
        await file.enable(header: Self.header)?.value
        let logger = Self.logger(writingTo: file)

        logger.info("kept")
        file.disable()
        logger.info("dropped")

        #expect(try Self.messages(in: directory) == ["kept"])
    }

    // MARK: - Helpers

    private struct Entry: Decodable {
        let msg: String
        let meta: [String: String]
        let lvl: String
        let label: String
        let src: String
    }

    private static func logger(writingTo file: ArchiveLogFile) -> Logger {
        Logger(label: "test") { label in
            ArchiveLogFileHandler(label: label, file: file)
        }
    }

    /// The lines of every log file in `directory`, one array per file in the order they were written.
    private static func fileLines(in directory: URL) throws -> [[String]] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted().map { name in
            let text = try String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8)
            return text.split(separator: "\n").map(String.init)
        }
    }

    /// Every log line, without the session header each file starts with.
    private static func entries(in directory: URL) throws -> [Entry] {
        try fileLines(in: directory).flatMap { lines in
            try lines.dropFirst().map { try JSONDecoder().decode(Entry.self, from: Data($0.utf8)) }
        }
    }

    private static func messages(in directory: URL) throws -> [String] {
        try entries(in: directory).map(\.msg)
    }
}
