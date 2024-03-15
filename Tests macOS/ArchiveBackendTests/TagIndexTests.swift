//
//  TagIndexTests.swift
//
//
//  Created by Julian Kahnert on 10.02.20.
//
// swiftlint:disable identifier_name

import XCTest

final class TagIndexTests: XCTestCase {

    func testElementsAdded() {
        var index = TagIndex<String>()

        index.add(["tag1", "tag2", "tag3"], for: "tag1")
        index.add(["tag4"], for: "tag1")

        index.add(["tag1"], for: "tag2")

        XCTAssertTrue(index.getElements(for: "tag3").isEmpty)
        XCTAssertEqual(index.getElements(for: "tag1").count, 4)
        XCTAssertEqual(index.getElements(for: "tag2").count, 1)
    }

    func testElementsAdded2() {
        var index = TagIndex<String>()

        index.add(["tag1", "tag2", "tag3"])

        XCTAssertTrue(index.getElements(for: "tag0").isEmpty)
        XCTAssertEqual(index.getElements(for: "tag1").count, 2)
        XCTAssertEqual(index.getElements(for: "tag2").count, 2)
        XCTAssertEqual(index.getElements(for: "tag3").count, 2)

        XCTAssertFalse(index.getElements(for: "tag3").contains("tag3"))
    }

    func testIndexAddPerformance() {

        self.measure {
            var index = TagIndex<String>()
            for i in 0..<10000 {
                index.add(["tag\(i + 1)", "tag\(i + 2)", "tag\(i + 3)"], for: "tag\(i)")
            }
        }
    }

    func testIndexAddSequencePerformance() {

        self.measure {
            var index = TagIndex<String>()
            for i in 0..<10000 {
                index.add(["tag\(i + 1)", "tag\(i + 2)", "tag\(i + 3)"])
            }
        }
    }

    func testIndexGetPerformance() {

        var index = TagIndex<String>()
        for i in 0..<10000 {
            index.add(["tag\(i + 1)", "tag\(i + 2)", "tag\(i + 3)"], for: "tag\(i)")
        }

        self.measure {
            for i in 0..<10000 {
                _ = index.getElements(for: "tag\(i)")
            }
        }
    }

    func testAtomicAdditions() {
        let index = Atomic(TagIndex<String>())

        DispatchQueue.main.async {
            index.mutate { $0.add(["tag4"], for: "tag1") }
        }
        DispatchQueue.global().async {
            index.mutate { $0.add(["tag5"], for: "tag1") }
        }
        DispatchQueue.global(qos: .background).async {
            index.mutate { $0.add(["tag6"], for: "tag1") }
        }
        DispatchQueue.main.async {
            index.mutate { $0.add(["tag1", "tag2", "tag3"], for: "tag1") }
        }

        sleep(1)

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
            XCTAssertTrue(index.value.getElements(for: "tag2").isEmpty)
            XCTAssertEqual(index.value.getElements(for: "tag1").count, 6)
        }
    }
}
