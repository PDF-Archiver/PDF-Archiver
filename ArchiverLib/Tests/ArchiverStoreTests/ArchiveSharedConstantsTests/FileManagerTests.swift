////
////  FileManagerTests.swift
////
////  Created by Julian Kahnert on 24.06.20.
////
//
// import XCTest
//
// final class FileManagerTests: XCTestCase {
//
//    var tempDir: URL?
//
//    override func setUpWithError() throws {
//        try super.setUpWithError()
//        // Put setup code here. This method is called before the invocation of each test method in the class.
//
//        // In UI tests it is usually best to stop immediately when a failure occurs.
//        continueAfterFailure = false
//
//        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
//
//        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
//
//        guard let tempDir = tempDir else { return }
//        for folderIndex in 0..<20 {
//            let folder = tempDir.appendingPathComponent("\(folderIndex)")
//            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
//            for _ in 0..<50 {
//                let file = folder.appendingPathComponent(UUID().uuidString)
//                try "TEST".write(to: file, atomically: true, encoding: .utf8)
//            }
//        }
//    }
//
//    override func tearDownWithError() throws {
//        try super.tearDownWithError()
//        // Put teardown code here. This method is called after the invocation of each test method in the class.
//        guard let tempDir = tempDir else { return }
//        try? FileManager.default.removeItem(at: tempDir)
//    }
//
//    func testGetFilesPerformanceAll() throws {
//        guard let path = tempDir else { return }
//        var files = [URL]()
//
//        measure {
//            files = FileManager.default.getFilesRecursive(at: path, with: [.ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsDownloadingKey, .fileSizeKey, .localizedNameKey])
//        }
//
//        XCTAssertEqual(files.count, 1000)
//    }
//
//    func testGetFilesPerformanceNoLocalizedName() throws {
//        guard let path = tempDir else { return }
//        var files = [URL]()
//
//        measure {
//            files = FileManager.default.getFilesRecursive(at: path, with: [.ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsDownloadingKey, .fileSizeKey])
//        }
//
//        XCTAssertEqual(files.count, 1000)
//    }
//
//    func testGetFilesPerformanceOnlyLocalizedName() throws {
//        guard let path = tempDir else { return }
//        var files = [URL]()
//
//        measure {
//            files = FileManager.default.getFilesRecursive(at: path, with: [.localizedNameKey])
//        }
//        XCTAssertEqual(files.count, 1000)
//    }
// }
