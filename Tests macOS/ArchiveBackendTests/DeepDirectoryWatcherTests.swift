//
//  DeepDirectoryWatcherTests.swift
//
//  Created by Julian Kahnert on 24.06.20.
//

@testable import PDFArchiver
import XCTest

final class DeepDirectoryWatcherTests: XCTestCase {

    var watcher: DirectoryDeepWatcher?
    var tempDir: URL?
    var files: [URL]?

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        guard let tempDir = tempDir else {
            XCTFail("TempDir could not be created.")
            return
        }
        for folderIndex in 0..<100 {
            let folder = tempDir.appendingPathComponent("\(folderIndex)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
            for _ in 0..<400 {
                let file = folder.appendingPathComponent(UUID().uuidString)
                try "TEST".write(to: file, atomically: true, encoding: .utf8)
            }
        }

        files = FileManager.default.getFilesRecursive(at: tempDir)
        XCTAssertEqual(files?.count, 40000)
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
        watcher = try DirectoryDeepWatcher(at: path)
        Task {
            for await _ in await watcher!.changedUrlStream {
                expectation.fulfill()
            }
        }

        try FileManager.default.removeItem(at: folderToRemove)

        wait(for: [expectation], timeout: 3)
        watcher = nil
    }

    func testFileRemove() throws {
        guard let path = tempDir else { return }

        let fileToRemove = try XCTUnwrap(files?.shuffled().first)

        let expectation = XCTestExpectation(description: "Document processing completed.")
        watcher = try DirectoryDeepWatcher(at: path)
        Task {
            for await changedUrl in await watcher!.changedUrlStream {
                guard changedUrl == fileToRemove.deletingLastPathComponent() else { return }
                expectation.fulfill()
            }
        }

        try FileManager.default.removeItem(at: fileToRemove)

        wait(for: [expectation], timeout: 3)
        watcher = nil
    }

    func testMultipleFileRemove() throws {
        guard let path = tempDir else { return }

        let filesToRemove = try XCTUnwrap(files?.shuffled().prefix(5))

        let parentFolders = Set(filesToRemove.map { $0.deletingLastPathComponent() })

        let expectations = parentFolders.reduce(into: [URL: XCTestExpectation]()) { (result, parentUrl) in
            result[parentUrl] = XCTestExpectation(description: "Document processing completed of \(parentUrl.absoluteString).")
        }

        watcher = try DirectoryDeepWatcher(at: path)
        Task {
            for await changedUrl in await watcher!.changedUrlStream {
                expectations[changedUrl]?.fulfill()
            }
        }

        for file in filesToRemove {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int.random(in: 0..<5))) {
                try? FileManager.default.removeItem(at: file)
            }
        }

        wait(for: expectations.map(\.value), timeout: 30)
        watcher = nil
    }

    func testFileRemoveLong() throws {
        guard let path = tempDir else { return }

        let expectation = XCTestExpectation(description: "Document processing completed.")

        watcher = try DirectoryDeepWatcher(at: path)
        Task {
            for await _ in await watcher!.changedUrlStream {
                expectation.fulfill()
            }
        }

        let fileToRemove = try XCTUnwrap(files?.shuffled().first)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(7)) {
            do {
                try FileManager.default.removeItem(at: fileToRemove)
            } catch {
                XCTFail("Error: \(error)")
            }
        }

        wait(for: [expectation], timeout: 20)
        watcher = nil
    }
}
