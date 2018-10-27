//
//  PDFArchiveViewerTests.swift
//  PDFArchiveViewerTests
//
//  Created by Julian Kahnert on 23.10.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import XCTest

class TestElement: Searchable {
    var searchTerm: String
    let hashValue: Int

    init(filename: String) {
        self.hashValue = filename.hashValue
        self.searchTerm = filename
    }

    static func == (lhs: TestElement, rhs: TestElement) -> Bool {
        return lhs.searchTerm == rhs.searchTerm
    }

}

class TestIndex: SearchIndex {
    typealias Element = TestElement

    var allSearchElements: Set<TestElement> = []
}

class PDFArchiveViewerTests: XCTestCase {

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testFilterPerformance1() {

        // create the search base
        let index = TestIndex()
        for idx in stride(from: 0, to: 100, by: 1) {
            index.allSearchElements.insert(TestElement(filename: "2018 05 12 document\(idx) beschreibung tag\(idx) tag\(idx * 11)"))
        }

        // performance test with a lot results
        var filteredElements = Set<TestElement>()
        self.measure {
            // Put the code you want to measure the time of here.
            filteredElements = index.filterBy("beschreibung")
        }
        XCTAssertEqual(filteredElements.capacity, 192)
    }

    func testFilterPerformance2() {

        // create the search base
        let index = TestIndex()
        for idx in stride(from: 0, to: 100, by: 1) {
            index.allSearchElements.insert(TestElement(filename: "2018 05 12 document\(idx) beschreibung tag\(idx) tag\(idx * 11)"))
        }

        // performance test with only a few results
        var filteredElements = Set<TestElement>()
        self.measure {
            // Put the code you want to measure the time of here.
            filteredElements = index.filterBy("tag11")
        }
        XCTAssertEqual(filteredElements.capacity, 3)
    }
}
