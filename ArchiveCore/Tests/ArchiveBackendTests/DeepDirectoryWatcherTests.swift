//
//  DeepDirectoryWatcherTests.swift
//
//  Created by Julian Kahnert on 24.06.20.
//

@testable import ArchiveBackend
import XCTest

final class DeepDirectoryWatcherTests: XCTestCase {

    var watcher: DirectoryDeepWatcher?
    var tempDir: URL?
    var files: [URL]?

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.

        tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString)

        guard let tempDir = tempDir else {
            XCTFail("TempDir could not be created.")
            return
        }
        for folderIndex in 0..<5 {
            let folder = tempDir.appendingPathComponent("\(folderIndex)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
            for _ in 0..<10 {
                let file = folder.appendingPathComponent(UUID().uuidString)
                try "TEST".write(to: file, atomically: true, encoding: .utf8)
            }
        }
        
        files = FileManager.default.getFilesRecursive(at: tempDir)
        XCTAssertEqual(files?.count, 50)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        guard let tempDir = tempDir else { return }
        try? FileManager.default.removeItem(at: tempDir)
        
        watcher = nil
    }

    func testFolderRemove() throws {
        guard let path = tempDir else { return }
        
        let folders = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        let folderToRemove = try XCTUnwrap(folders.shuffled().first)
        
        let expectation = XCTestExpectation(description: "Document processing completed.")
        watcher = DirectoryDeepWatcher.watch(path, withHandler: { _ in
            expectation.fulfill()
        })
        
        try FileManager.default.removeItem(at: folderToRemove)
        
        wait(for: [expectation], timeout: 3)
    }
    
    func testFileRemove() throws {
        guard let path = tempDir else { return }
        
        let expectation = XCTestExpectation(description: "Document processing completed.")
        watcher = DirectoryDeepWatcher.watch(path, withHandler: { _ in
            expectation.fulfill()
        })
        
        let fileToRemove = try XCTUnwrap(files?.shuffled().first)
        try FileManager.default.removeItem(at: fileToRemove)
        
        wait(for: [expectation], timeout: 3)
    }
    
    func testFileRemoveLong() throws {
        guard let path = tempDir else { return }
        
        let expectation = XCTestExpectation(description: "Document processing completed.")
        watcher = DirectoryDeepWatcher.watch(path, withHandler: { _ in
            expectation.fulfill()
        })
        
        let fileToRemove = try XCTUnwrap(files?.shuffled().first)
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(7)) {
            do {
                try FileManager.default.removeItem(at: fileToRemove)
            } catch {
                XCTFail("Error: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 10)
    }
}
