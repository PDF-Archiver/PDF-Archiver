//
//  PDFArchiverTests.swift
//  PDFArchiverTests
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import XCTest
@testable import PDFArchiver

class DocumentTests: XCTestCase {

    var tag1 = Tag(name: "tag1", count: 1)
    var tag2 = Tag(name: "tag2", count: 2)
    var tag3 = Tag(name: "tag3", count: 3)
    lazy var tags = Set([tag1, tag2, tag3])

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // reset the tags
        self.tag1 = Tag(name: "tag1", count: 1)
        self.tag2 = Tag(name: "tag2", count: 2)
        self.tag3 = Tag(name: "tag3", count: 3)
        self.tags = Set([self.tag1, self.tag2, self.tag3])
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testDocumentNameParsing() {
        let path = URL(fileURLWithPath: "~/Downloads/2010-05-12--example-description__tag1_tag2.pdf")
        let document = Document(path: path, availableTags: &self.tags)

        // description
        XCTAssertEqual(document.specification, "example-description")

        // tags
        var documentTagNames = [String]()
        var documentTagCounts = [Int]()
        for tag in document.documentTags.sorted(by: { $0.name < $1.name}) {
            documentTagNames.append(tag.name)
            documentTagCounts.append(tag.count)
        }
        XCTAssertEqual(documentTagNames, ["tag1", "tag2"])
        XCTAssertEqual(documentTagCounts, [2, 3])

        // date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: "2010-05-12")
        XCTAssertEqual(document.date, date)
    }

    func testDocumentDateParsingFormat1() {
        let path = URL(fileURLWithPath: "~/Downloads/2010-05-12 example filename.pdf")
        let document = Document(path: path, availableTags: &self.tags)

        // date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: "2010-05-12")
        XCTAssertEqual(document.date, date)
    }

    func testDocumentDateParsingFormat2() {
        let path = URL(fileURLWithPath: "~/Downloads/2010_05_12 example filename.pdf")
        let document = Document(path: path, availableTags: &self.tags)

        // date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: "2010-05-12")
        XCTAssertEqual(document.date, date)
    }

    func testDocumentDateParsingFormat3() {
        let path = URL(fileURLWithPath: "~/Downloads/20100512 example filename.pdf")
        let document = Document(path: path, availableTags: &self.tags)

        // date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: "2010-05-12")
        XCTAssertEqual(document.date, date)
    }

    func testDocumentDateParsingScanSnapFormat() {
        let path = URL(fileURLWithPath: "~/Downloads/2010_05_12_15_17.pdf")
        let document = Document(path: path, availableTags: &self.tags)

        // date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: "2010-05-12")
        XCTAssertEqual(document.date, date)
    }

    func testDocumentRenaming() {
        let path = URL(fileURLWithPath: "~/Downloads/2010-05-12--example-description__tag1_tag2.pdf")
        var tags = Set([tag1, tag2, tag3])
        let document = Document(path: path, availableTags: &tags)

        var testArchivePath = URL(fileURLWithPath: "~/Downloads/Archive/")
        do {
            let (newBasepath, filename) = try document.getRenamingPath(archivePath: testArchivePath)
            testArchivePath.appendPathComponent("2010")
            XCTAssertEqual(newBasepath, testArchivePath)

            XCTAssertEqual(filename, path.lastPathComponent)
        } catch {
            XCTAssert(false)
        }
    }
}
