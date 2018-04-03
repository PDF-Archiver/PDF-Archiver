//
//  PreferencesTests.swift
//  PDF ArchiverTests
//
//  Created by Julian Kahnert on 26.03.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import XCTest
@testable import PDF_Archiver

class PreferencesTests: XCTestCase, TagsDelegate {
    var tagList = Set<Tag>()

    func setTagList(tagList: Set<Tag>) {
        self.tagList = tagList
    }

    func getTagList() -> Set<Tag> {
        var tags = Set<Tag>()

        tags.insert(Tag(name: "tag1", count: 1))
        tags.insert(Tag(name: "tag2", count: 2))
        tags.insert(Tag(name: "tag3", count: 3))

        return tags
    }

    override func setUp() {
        super.setUp()

        self.tagList = []
    }

    func testLoad() {
//        print(UserDefaults.standard.url(forKey: "archivePath"))
        print(self.tagList)
        var prefs = Preferences()
        prefs.load()
        print(self.tagList)
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
