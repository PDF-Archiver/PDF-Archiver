//
//  DocumentFilterTests.swift
//  
//
//  Created by Julian Kahnert on 25.08.20.
//

import Foundation
import XCTest

final class DocumentFilterTests: XCTestCase {

    func testSingleDocumentTagFilter() {
        let documents = [
            Document(path: URL(fileURLWithPath: "~/Downloads/2018-05-12--example-description__tag1_tag2.pdf"), taggingStatus: .tagged, downloadStatus: .local, byteSize: 0),
            Document(path: URL(fileURLWithPath: "~/Downloads/2018-05-12--example-description__tag2_tag3.pdf"), taggingStatus: .tagged, downloadStatus: .local, byteSize: 0),
            Document(path: URL(fileURLWithPath: "~/Downloads/2018-05-12--example-description__tag=1_TaG3.pdf"), taggingStatus: .tagged, downloadStatus: .local, byteSize: 0)
        ]
        documents[0].tags = ["tag1", "tag2"]
        documents[1].tags = ["tag2", "tag3"]
        documents[2].tags = ["tag=1", "TaG3"]

        XCTAssertEqual(documents.filter(by: [.tag("tag1")]), [documents[0]])
        XCTAssertEqual(documents.filter(by: [.tag("TaG1")]), [documents[0]])
        XCTAssertEqual(documents.filter(by: [.tag("tag=1")]), [documents[2]])
        XCTAssertEqual(documents.filter(by: [.tag("tag2")]), [documents[0], documents[1]])

        XCTAssertEqual(documents.filter(by: [.tag("tag3")]), [documents[1], documents[2]])
    }

    func testMultipleDocumentTagFilters() {
        let documents = [
            Document(path: URL(fileURLWithPath: "~/Downloads/2018-05-12--example-description__tag1_tag2.pdf"), taggingStatus: .tagged, downloadStatus: .local, byteSize: 0),
            Document(path: URL(fileURLWithPath: "~/Downloads/2018-05-12--example-description__tag2_tag3.pdf"), taggingStatus: .tagged, downloadStatus: .local, byteSize: 0),
            Document(path: URL(fileURLWithPath: "~/Downloads/2018-05-12--example-description__tag=1_tAg3.pdf"), taggingStatus: .tagged, downloadStatus: .local, byteSize: 0),
            Document(path: URL(fileURLWithPath: "~/Downloads/2018-05-12--example-description__tag1_tag2_tag3.pdf"), taggingStatus: .tagged, downloadStatus: .local, byteSize: 0)
        ]
        documents[0].tags = ["tag1", "tag2"]
        documents[1].tags = ["tag2", "tag3"]
        documents[2].tags = ["tag=1", "tAg3"]
        documents[3].tags = ["tag1", "tag2", "tag3"]

        XCTAssertEqual(documents.filter(by: [.tag("tag3"), .tag("tag=1")]), [documents[2]])
        XCTAssertEqual(documents.filter(by: [.tag("tag1"), .tag("tag=1")]), [])
        XCTAssertEqual(documents.filter(by: [.tag("tag1"), .tag("tag2")]), [documents[0], documents[3]])
    }

//    func testLowercasePerformance() throws {
//
//        let tags = repeatElement(UUID().uuidString, count: 100_000)
//
//        var lowercasedTags: [String] = []
//        measure {
//            lowercasedTags = tags.map { $0.lowercased() }
//        }
//
//        XCTAssertTrue(!lowercasedTags.isEmpty)
//    }
}
