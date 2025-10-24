//
//  ExampleTests.swift
//  ContentExtractorExampleTests
//
//  Basic tests for the example package
//

import XCTest
@testable import ContentExtractorExample

final class ExampleTests: XCTestCase {

    @available(iOS 26, macOS 26, *)
    func testMockTagCountTool() async throws {
        let tool = MockTagCountTool()

        // Test with default minTagCount (3)
        let result1 = try await tool.call(arguments: MockTagCountTool.Arguments(minTagCount: nil))
        XCTAssertTrue(result1.contains("rechnung"))
        XCTAssertTrue(result1.contains("'tagName': count"))

        // Test with higher minTagCount
        let result2 = try await tool.call(arguments: MockTagCountTool.Arguments(minTagCount: 20))
        XCTAssertTrue(result2.contains("rechnung"))
        XCTAssertFalse(result2.contains("elektronik")) // count is only 3
    }
}
