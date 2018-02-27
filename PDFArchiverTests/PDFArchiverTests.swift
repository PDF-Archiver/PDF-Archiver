//
//  PDFArchiverTests.swift
//  PDFArchiverTests
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2017 Julian Kahnert. All rights reserved.
//

import XCTest
@testable import PDF_Archiver

class PDFArchiverTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testDocumentDescription() {
        let document = Document(path: URL(fileURLWithPath: "~/Downloads/test.pdf"))
        let exampleString = "Das hier ist ein öffentlicher TÄst!"
        document.documentDescription = exampleString
        
        XCTAssertEqual(document.documentDescription, "das-hier-ist-ein-oeffentlicher-taest")
        XCTAssertNotEqual(document.documentDescription, exampleString)
    }

    func testDocumentNameParsing() {
        let path = URL(fileURLWithPath: "~/Downloads/2010-05-12--example-description__tag1_tag2.pdf")
        let document = Document(path: path)

        // description
        XCTAssertEqual(document.documentDescription, "example-description")
        
        // tags
        var documentTags = [String]()
        for tag in document.documentTags ?? [] {
            documentTags.append(tag.name)
        }
        XCTAssertEqual(documentTags, ["tag1", "tag2"])
        
        // date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: "2010-05-12")
        XCTAssertEqual(document.documentDate, date)
    }
    
    func testDocumentRenaming() {
        let path = URL(fileURLWithPath: "~/Downloads/2010-05-12--example-description__tag1_tag2.pdf")
        let document = Document(path: path)
        
        var testArchivePath = URL(fileURLWithPath: "~/Downloads/Archive/")
        
        let (new_basepath, filename) = try! document.getRenamingPath(archivePath: testArchivePath)
        testArchivePath.appendPathComponent("2010")
        XCTAssertEqual(new_basepath, testArchivePath)
        
        XCTAssertEqual(filename, path.lastPathComponent)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
