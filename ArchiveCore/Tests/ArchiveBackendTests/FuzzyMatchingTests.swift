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
    private static let testFilenames: [String] = {
        (try! String(contentsOf: testFileUrl))
//            .split(separator: "\n")
//        return files.split { $0.isNewline }
            .split { $0.isNewline }
            .map(String.init)
    }()

    override func setUp() {
        super.setUp()
    }

    func testPerformance1() {
        var results = [(item: [String.UTF8View.Element], score: Int)]()
        let text = Self.testFilenames.map { Array($0.utf8) }

        measure {
            results = text.fuzzyMatch("swift")
        }

        XCTAssertTrue(!results.isEmpty)
    }

    func testPerformance2() {
        var results = [String]()
        let text = Self.testFilenames

        measure {
            results = text.fuzzyMatchSorted("swift")
        }

        XCTAssertTrue(!results.isEmpty)
    }

    func testPerformance3() {
        let text = Self.testFilenames
        var tmp = [[String.UTF8View.Element]]()

        measure {
            tmp = text.map { Array($0.utf8) }
        }

        XCTAssertTrue(!tmp.isEmpty)
    }
}
