//
//  StatisticsTests.swift
//  
//
//  Created by Julian Kahnert on 27.12.20.
//

import Foundation
import XCTest

final class StatisticsTests: XCTestCase {

    func testEmptyDocuments() throws {
        let viewModel = StatisticsViewModel(documents: [])

        XCTAssertEqual(viewModel.untaggedDocumentCount, 0)
        XCTAssertEqual(viewModel.taggedDocumentCount, 0)

        XCTAssertEqual(viewModel.topTags.count, 0)
        XCTAssertEqual(viewModel.topYears.count, 0)
    }

    func testValidDocuments() throws {
        let viewModel = StatisticsViewModel(documents: [
            Document.createWithInfo(taggingStatus: .tagged, tags: ["tag1"], folderName: "2020"),
            Document.createWithInfo(taggingStatus: .tagged, tags: ["tag1", "tag6"], folderName: "2020"),
            Document.createWithInfo(taggingStatus: .tagged, tags: ["tag1", "tag2"], folderName: "2020"),
            Document.createWithInfo(taggingStatus: .tagged, tags: ["tag2", "tag3"], folderName: "2020"),
            Document.createWithInfo(taggingStatus: .tagged, tags: ["tag5", "tag6"], folderName: "2020"),
            Document.createWithInfo(taggingStatus: .tagged, tags: ["tag1", "tag6"], folderName: "2021"),
            Document.createWithInfo(taggingStatus: .untagged, tags: ["tag1", "tag2"], folderName: "2020")
        ])

        XCTAssertEqual(viewModel.untaggedDocumentCount, 1)
        XCTAssertEqual(viewModel.taggedDocumentCount, 6)

        XCTAssertEqual(viewModel.topTags.count, 3)
        XCTAssertEqual(viewModel.topTags.sorted(by: { $0.1 > $1.1 }).map(\.0), ["tag1", "tag6", "tag2"])
        XCTAssertEqual(viewModel.topYears.count, 2)
    }
}
