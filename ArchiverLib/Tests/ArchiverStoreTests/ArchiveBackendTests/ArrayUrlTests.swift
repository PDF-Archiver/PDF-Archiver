//
//  ArrayUrlTests.swift
//
//
//  Created by Julian Kahnert on 22.08.20.
//

import Foundation
import Testing

@testable import ArchiverStore

@MainActor
struct ArrayURLTests {
    @Test
    func testParents() async throws {
        // swiftlint:disable force_unwrapping
        let url1 = URL(string: "/test/folder1/archive/untagged")!
        let url2 = URL(string: "/test/folder1/archive")!
        let url3 = URL(string: "/test/folder2/scans")!
        let url4 = URL(string: "/test/folder1/archive/untagged/temp")!
        let url5 = URL(string: "/test/folder2")!
        // swiftlint:enable force_unwrapping

        let folders = [url1, url2, url3, url4, url5].getUniqueParents()

        #expect(folders.contains(url2))
        #expect(folders.contains(url5))
        #expect(folders.count == 2)
    }
}
