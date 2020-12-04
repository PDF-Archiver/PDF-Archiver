//
//  FuzzyMatchingTests.swift
//  
//
//  Created by Julian Kahnert on 25.08.20.
//
// swiftlint:disable force_try force_unwrapping

@testable import ArchiveBackend
import Foundation
import XCTest

final class FuzzyMatchingTests: XCTestCase {

    private static let testFileUrl = URL(string: "https://raw.githubusercontent.com/objcio/S01E216-quick-open-optimizing-performance-part-2/master/QuickOpen/linux.txt")!
    private static let testFilenames: [String]? = {
        guard let content = try? String(contentsOf: testFileUrl) else { return nil }
        return content
            .split { $0.isNewline }
            .map(String.init)
    }()

    override func setUp() {
        super.setUp()
    }

    func testPerformance1() throws {
        guard let testFilenames = Self.testFilenames else { throw XCTSkip("Could not fetch linux file content.") }

        var results = [(item: [String.UTF8View.Element], score: Int)]()
        let text = testFilenames.map { Array($0.utf8) }

        measure {
            results = text.fuzzyMatch("swift")
        }

        XCTAssertTrue(!results.isEmpty)
    }

    func testPerformance2() throws {
        var results = [String]()
        guard let testFilenames = Self.testFilenames else { throw XCTSkip("Could not fetch linux file content.") }

        measure {
            results = testFilenames.fuzzyMatchSorted("swift")
        }

        XCTAssertTrue(!results.isEmpty)
    }

    func testPerformance3() throws {
        guard let testFilenames = Self.testFilenames else { throw XCTSkip("Could not fetch linux file content.") }
        var tmp = [[String.UTF8View.Element]]()

        measure {
            tmp = testFilenames.map { Array($0.utf8) }
        }

        XCTAssertTrue(!tmp.isEmpty)
    }
}
