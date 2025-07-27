////
////  FileManagerTests.swift
////  
////
////  Created by Julian Kahnert on 07.01.21.
////
//
//// *** FOLDERSTRUCTURE ***
////
//// sourcefolder
////   |
////   - file1
////   - subfolder
////       - file2
////       - subsubfolder
////          |
////          - file22
////
//// destinationfolder
////   |
////   - file3
////   - subfolder
////       - file4
////       - file5
////
//// resultingfolder
////   |
////   - file1
////   - file3
////   - subfolder
////       - file2
////       - file4
////       - file5
////       - subsubfolder
////          |
////          - file22
//
//import Foundation
//import XCTest
//
//final class FileManagerMoveTests: XCTestCase {
//
//    var tempDir: URL?
//    var files: [URL]?
//
//    override func setUpWithError() throws {
//        try super.setUpWithError()
//        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
//
//        let url = try XCTUnwrap(tempDir)
//
//        let source = url.appendingPathComponent("source")
//        try source.createDirectory()
//        try source.appendingPathComponent("file1").writeFile()
//        try source.appendingPathComponent("subfolder").createDirectory()
//        try source.appendingPathComponent("subfolder").appendingPathComponent("file2").writeFile()
//        try source.appendingPathComponent("subfolder").appendingPathComponent("subsubfolder").createDirectory()
//        try source.appendingPathComponent("subfolder").appendingPathComponent("subsubfolder").appendingPathComponent("file22").writeFile()
//
//        let destination = url.appendingPathComponent("destination")
//        try destination.createDirectory()
//        try destination.appendingPathComponent("file3").writeFile()
//        try destination.appendingPathComponent("subfolder").createDirectory()
//        try destination.appendingPathComponent("subfolder").appendingPathComponent("file4").writeFile()
//        try destination.appendingPathComponent("subfolder").appendingPathComponent("file5").writeFile()
//
//        let files = FileManager.default.getFilesRecursive(at: url)
//        XCTAssertEqual(files.count, 6)
//    }
//
//    override func tearDownWithError() throws {
//        try super.tearDownWithError()
//        guard let url = tempDir else { return }
//        try FileManager.default.removeItem(at: url)
//    }
//
//    func testFolderMerge() throws {
//        let url = try XCTUnwrap(tempDir)
//
//        let source = url.appendingPathComponent("source")
//        let destination = url.appendingPathComponent("destination")
//
//        XCTAssert(FileManager.default.directoryExists(at: source))
//        XCTAssert(FileManager.default.directoryExists(at: destination))
//
//        let files = FileManager.default.getFilesRecursive(at: url)
//        XCTAssertEqual(files.count, 6)
//
//        try FileManager.default.moveContents(of: source, to: destination)
//
//        let files2 = FileManager.default.getFilesRecursive(at: url)
//        XCTAssertEqual(files2.count, 6)
//
//        // swiftlint:disable identifier_name
//        let fm = FileManager.default
//        XCTAssert(fm.fileExists(at: destination.appendingPathComponent("file1")))
//        XCTAssert(fm.fileExists(at: destination.appendingPathComponent("file3")))
//        XCTAssert(fm.directoryExists(at: destination.appendingPathComponent("subfolder")))
//        XCTAssert(fm.fileExists(at: destination.appendingPathComponent("subfolder").appendingPathComponent("file2")))
//        XCTAssert(fm.fileExists(at: destination.appendingPathComponent("subfolder").appendingPathComponent("file4")))
//        XCTAssert(fm.fileExists(at: destination.appendingPathComponent("subfolder").appendingPathComponent("file5")))
//        XCTAssert(fm.directoryExists(at: destination.appendingPathComponent("subfolder").appendingPathComponent("subsubfolder")))
//        XCTAssert(fm.fileExists(at: destination.appendingPathComponent("subfolder").appendingPathComponent("subsubfolder").appendingPathComponent("file22")))
//    }
//}
