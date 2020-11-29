//
//  SearchTests.swift
//  ArchiveLibTests
//
//  Created by Julian Kahnert on 14.11.18.
//

import ArchiveBackend
import XCTest

final class TestElement: Searchitem, Hashable, CustomDebugStringConvertible {

    let filename: String
    let term: Term

    init(filename: String) {
        self.filename = filename
        self.term = filename.utf8.map { UInt8($0) }
    }

    var debugDescription: String {
        filename
    }

    static func == (lhs: TestElement, rhs: TestElement) -> Bool {
        return lhs.term == rhs.term
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(term)
    }
}

final class SearchTests: XCTestCase {

    func testSearch0() {

        // prepare
        let elements = [
            "2018 05 12 kitchen table bill ikea",
            "2018 01 07 tom tailor shirt bill",
            "kitchen wood table",
            "new mac mini",
            "couch table",
            "lamp",
            "lamp",
            "lamp",
            "lamp",
            "lamp",
            "lamp",
            "lamp"
        ]

        // act
        let foundElements = elements.fuzzyMatch("bill").map(\.item)

        // assert
        XCTAssertTrue(foundElements.contains(elements[0]))
        XCTAssertTrue(foundElements.contains(elements[1]))
    }

    func testSearch1() {

        // prepare
        let element1 = TestElement(filename: "2018 05 12 kitchen table bill ikea")
        let element2 = TestElement(filename: "2018 01 07 tom tailor shirt bill")

        // act
        let foundElements = [element1, element2].fuzzyMatch("bill").map(\.item)

        // assert
        XCTAssertTrue(foundElements.contains(element1))
        XCTAssertTrue(foundElements.contains(element2))
    }

    func testSearch2() {

        // prepare
        let element1 = TestElement(filename: "2018 05 12 kitchen table bill ikea")
        let element2 = TestElement(filename: "2018 01 07 tom tailor shirt bill")

        // act
        let foundElements = [element1, element2].fuzzyMatch("bill").map(\.item)

        // assert
        XCTAssertTrue(foundElements.contains(element1))
        XCTAssertTrue(foundElements.contains(element2))
    }

    func testSearch3() {

        // prepare
        let element1 = TestElement(filename: "2018 05 12 kitchen table bill ikea")
        let element2 = TestElement(filename: "2018 01 07 tom tailor shirt bill")

        // act
        let foundElements = [element1, element2].fuzzyMatch("bill").map(\.item)

        // assert
        XCTAssertTrue(foundElements.contains(element1))
        XCTAssertTrue(foundElements.contains(element2))
    }

    func testSearchCPUCoreCount1() {

        // prepare
        let elements = stride(from: 0, to: ProcessInfo.processInfo.activeProcessorCount + 4, by: 1)
            .map { "2018 05 \($0) kitchen table bill ikea" }

        // act
        let foundElements = elements.fuzzyMatch("bill").map(\.item)

        // assert
        XCTAssertEqual(foundElements.count, elements.count)
        XCTAssertEqual(foundElements.sorted(), elements.sorted())
    }

    func testSearchCPUCoreCount2() {

        // prepare
        let elements = stride(from: 0, to: ProcessInfo.processInfo.activeProcessorCount - 2, by: 1)
            .map { "2018 05 \($0) kitchen table bill ikea" }

        // act
        let foundElements = elements.fuzzyMatch("bill").map(\.item)

        // assert
        XCTAssertEqual(foundElements.count, elements.count)
        XCTAssertEqual(foundElements.sorted(), elements.sorted())
    }
    
    func testSearchCPUCoreCount3() {

        // prepare
        let elements = stride(from: 0, to: ProcessInfo.processInfo.activeProcessorCount, by: 1)
            .map { "2018 05 \($0) kitchen table bill ikea" }

        // act
        let foundElements = elements.fuzzyMatch("bill").map(\.item)

        // assert
        XCTAssertEqual(foundElements.count, elements.count)
        XCTAssertEqual(foundElements.sorted(), elements.sorted())
    }


    func testFilterPerformance1() {

        // create the search base
        let elements = stride(from: 0, to: 100, by: 1)
            .map { idx in
                TestElement(filename: "2018 05 12 document\(idx) description tag\(idx) tag\(idx * 11)")
            }

        // performance test with a lot results
        var filteredElements = [TestElement]()
        self.measure {
            // Put the code you want to measure the time of here.
            filteredElements = elements.fuzzyMatch("description").map(\.item)
        }
        XCTAssertEqual(filteredElements.count, 100)
    }

    func testFilterPerformance2() {

        // create the search base
        let elements = stride(from: 0, to: 100, by: 1)
            .map { idx in
                TestElement(filename: "2018 05 12 document\(idx) description tag\(idx) tag\(idx * 11)")
            }

        // performance test with only a few results
        var filteredElements = [TestElement]()
        self.measure {
            // Put the code you want to measure the time of here.
            filteredElements = elements.fuzzyMatch("tag11").map(\.item)
        }
        XCTAssertEqual(filteredElements.count, 19)
    }
}
