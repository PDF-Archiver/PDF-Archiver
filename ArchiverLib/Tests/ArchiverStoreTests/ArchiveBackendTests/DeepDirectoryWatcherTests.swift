@testable import ArchiverStore
import Foundation
import Testing

/// Tests of the DeepDirectoryWatcher tests
///
/// **Attention:** These tests are skipped, since the current implementation of the `DirectoryDeepWatcher` will trigger too oftern.
/// We handle this by debouncing these calls.
@Suite(.serialized)
@MainActor
final class DeepDirectoryWatcherTests {

    var watcher: DirectoryDeepWatcher?
    var tempDir: URL?
    var files: [URL]?

    init() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        guard let tempDir = tempDir else {
            Issue.record("TempDir could not be created.")
            return
        }
        let folderCount = 3
        let fileCount = 2
        for folderIndex in 0..<3 {
            let folder = tempDir.appendingPathComponent("\(folderIndex)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
            for _ in 0..<fileCount {
                let file = folder.appendingPathComponent(UUID().uuidString)
                try "TEST".write(to: file, atomically: true, encoding: .utf8)
            }
        }

        files = FileManager.default.getFilesRecursive(at: tempDir)
        #expect(files?.count == folderCount * fileCount)
    }

    deinit {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        guard let tempDir = tempDir else { return }
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test(.enabled(if: false), .timeLimit(.minutes(1)))
    func removeSingleFolder() async throws {
        guard let tempDir else {
            Issue.record("Engine could not find temp folder")
            return
        }

        let folders = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        let folderToRemove = try #require(folders.shuffled().first)

        watcher = try DirectoryDeepWatcher(at: tempDir)
        Task {
            try await Task.sleep(for: .milliseconds(10))
            try FileManager.default.removeItem(at: folderToRemove)

            try await Task.sleep(for: .milliseconds(10))
            await self.watcher?.stop()
        }

        await confirmation("folder change", expectedCount: 1) { folderChange in
            for await change in await watcher!.changedUrlStream {
                #expect(change.standardizedFileURL == folderToRemove.deletingLastPathComponent().standardizedFileURL)
                folderChange()
            }
        }
        watcher = nil
    }

    @Test(.enabled(if: false))
    func removeMultipleFolders() async throws {
        guard let tempDir else {
            Issue.record("Engine could not find temp folder")
            return
        }

        let folderToRemove0 = tempDir.appendingPathComponent("0")
        let folderToRemove1 = tempDir.appendingPathComponent("1")

        watcher = try DirectoryDeepWatcher(at: tempDir)
        Task {
            try await Task.sleep(for: .milliseconds(10))
            try FileManager.default.removeItem(at: folderToRemove0)
            try await Task.sleep(for: .milliseconds(5))
            try FileManager.default.removeItem(at: folderToRemove1)

            try await Task.sleep(for: .milliseconds(10))
            await self.watcher?.stop()
        }

        await confirmation("folder change", expectedCount: 2) { folderChange in
            for await change in await watcher!.changedUrlStream {
                #expect(change.standardizedFileURL == folderToRemove0.deletingLastPathComponent().standardizedFileURL || change.standardizedFileURL == folderToRemove1.deletingLastPathComponent().standardizedFileURL)
                folderChange()
            }
        }
        watcher = nil
    }

    @Test(.enabled(if: false))
    func testFileRemove() async throws {
        guard let tempDir else {
            Issue.record("Engine could not find temp folder")
            return
        }

        let fileToRemove = try #require(files?.shuffled().first)

        watcher = try DirectoryDeepWatcher(at: tempDir)
        Task {
            try await Task.sleep(for: .milliseconds(10))
            try FileManager.default.removeItem(at: fileToRemove)

            try await Task.sleep(for: .milliseconds(10))
            await self.watcher?.stop()
        }

        await confirmation("folder change", expectedCount: 1) { folderChange in
            for await change in await watcher!.changedUrlStream {
                #expect(change.standardizedFileURL == fileToRemove.deletingLastPathComponent().standardizedFileURL)
                folderChange()
            }
        }
        watcher = nil
    }

    @Test(.enabled(if: false))
    func testFileAdded() async throws {
        guard let tempDir else {
            Issue.record("Engine could not find temp folder")
            return
        }

        let file = try #require(files?.shuffled().first)
        let newFile = file.deletingLastPathComponent().appendingPathComponent("new-file")

        watcher = try DirectoryDeepWatcher(at: tempDir)
        Task {
            try await Task.sleep(for: .milliseconds(10))
            try "TEST".write(to: newFile, atomically: true, encoding: .utf8)

            try await Task.sleep(for: .milliseconds(10))
            await self.watcher?.stop()
        }

        await confirmation("folder change", expectedCount: 1) { folderChange in
            for await change in await watcher!.changedUrlStream {
                #expect(change.standardizedFileURL == newFile.deletingLastPathComponent().standardizedFileURL)
                folderChange()
            }
        }
        watcher = nil
    }
}
