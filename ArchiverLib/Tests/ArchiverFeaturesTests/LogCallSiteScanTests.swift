//
//  LogCallSiteScanTests.swift
//  ArchiverLib
//
//  Complements the `no_paths_in_logs` SwiftLint rule (single-line only) by scanning whole,
//  potentially multi-line log calls - a `metadata:` dictionary spread over several lines hides
//  a raw path from SwiftLint's per-line regex, but not from this.
//

import Foundation
import Testing

@Suite("Log call sites stay free of raw paths")
struct LogCallSiteScanTests {
    @Test("no log call interpolates lastPathComponent, .path or absoluteString")
    func noRawPathsInLogCalls() throws {
        let violations = try Self.scan(Self.sourcesDirectory())
        #expect(violations.isEmpty, "\(violations.joined(separator: "\n"))")
    }

    /// `#filePath` resolves to .../ArchiverLib/Tests/ArchiverFeaturesTests/LogCallSiteScanTests.swift
    private static func sourcesDirectory() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // ArchiverFeaturesTests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources")
    }

    private static func scan(_ directory: URL) throws -> [String] {
        let callStart = /\b(?:log|Logger(?:\.[A-Za-z]+)?)\.[A-Za-z]+\(/
        let forbiddenToken = /lastPathComponent|\.path\b|\.path\(\)|absoluteString/

        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return ["Could not enumerate \(directory.path)"]
        }

        var violations: [String] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift", fileURL.lastPathComponent != "LogRedact.swift" else { continue }

            let text = try String(contentsOf: fileURL, encoding: .utf8)

            for match in text.matches(of: callStart) {
                let openParen = text.index(before: match.range.upperBound)
                guard let closeParen = Self.matchingCloseParen(in: text, openAt: openParen) else { continue }

                let callBody = text[openParen...closeParen]
                guard callBody.contains(forbiddenToken) else { continue }

                let line = text[text.startIndex..<match.range.lowerBound].reduce(into: 1) { count, char in
                    if char == "\n" { count += 1 }
                }
                violations.append("\(fileURL.path):\(line)")
            }
        }
        return violations
    }

    /// Walks forward from an opening `(`, tracking nesting depth, to the paren that closes it.
    private static func matchingCloseParen(in text: String, openAt: String.Index) -> String.Index? {
        var depth = 0
        var index = openAt
        while index < text.endIndex {
            switch text[index] {
            case "(":
                depth += 1

            case ")":
                depth -= 1
                if depth == 0 { return index }

            default:
                break
            }
            index = text.index(after: index)
        }
        return nil
    }
}
