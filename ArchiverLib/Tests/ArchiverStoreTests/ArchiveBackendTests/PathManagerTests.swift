//
//  PDFProcessingTests.swift
//
//
//  Created by Julian Kahnert on 01.12.20.
//

import Foundation
import PDFKit
import Testing

@testable import ArchiverStore

@MainActor
final class PathManagerTests {
    nonisolated static let tempFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    init() throws {
        try FileManager.default.createDirectory(at: Self.tempFolder, withIntermediateDirectories: true, attributes: nil)
    }

    deinit {
        try! FileManager.default.removeItem(at: Self.tempFolder)
    }

    #if os(macOS)
    @Test
    func testArchiveChangeMacOS() throws {
        let currentArchiveFolder = Self.tempFolder.appendingPathComponent("CurrentArchive")
        try FileManager.default.createDirectory(at: currentArchiveFolder, withIntermediateDirectories: true, attributes: nil)
        UserDefaults.archivePathType = .local(currentArchiveFolder)

        let archiveUrl = try PathManager.shared.getArchiveUrl()

        // folders that should be copied
        try FileManager.default.createDirectory(at: archiveUrl.appendingPathComponent("untagged"), withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: archiveUrl.appendingPathComponent("2020"), withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: archiveUrl.appendingPathComponent("2019"), withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: archiveUrl.appendingPathComponent("2018"), withIntermediateDirectories: true, attributes: nil)
        // folders that should not be copied
        try FileManager.default.createDirectory(at: archiveUrl.appendingPathComponent("inbox"), withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: archiveUrl.appendingPathComponent("test"), withIntermediateDirectories: true, attributes: nil)

        let type = PathManager.ArchivePathType.local(Self.tempFolder.appendingPathComponent("NewArchive"))

        let newArchiveUrl = try type.getArchiveUrl()
        try FileManager.default.createFolderIfNotExists(newArchiveUrl)

        try PathManager.shared.setArchiveUrl(with: type)

        let urls = try FileManager.default.contentsOfDirectory(at: newArchiveUrl, includingPropertiesForKeys: nil, options: [])
        #expect(urls.contains(where: { $0.lastPathComponent == "untagged" }))
        #expect(urls.contains(where: { $0.lastPathComponent == "2020" }))
        #expect(urls.contains(where: { $0.lastPathComponent == "2019" }))
        #expect(urls.contains(where: { $0.lastPathComponent == "2018" }))

        #expect(false == urls.contains(where: { $0.lastPathComponent == "inbox" }))
        #expect(false == urls.contains(where: { $0.lastPathComponent == "test" }))
    }
    #endif

    #if !os(macOS)
    @Test
    func testPDFInput() throws {
        let currentArchiveFolder = Self.tempFolder.appendingPathComponent("CurrentArchive")
        try FileManager.default.createDirectory(at: currentArchiveFolder, withIntermediateDirectories: true, attributes: nil)
        UserDefaults.archivePathType = .local(currentArchiveFolder)

        let archiveUrl = try PathManager.shared.getArchiveUrl()

        // folders that should be copied
        try FileManager.default.createDirectory(at: archiveUrl.appendingPathComponent("untagged"), withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: archiveUrl.appendingPathComponent("2020"), withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: archiveUrl.appendingPathComponent("2019"), withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: archiveUrl.appendingPathComponent("2018"), withIntermediateDirectories: true, attributes: nil)
        // folders that should not be copied
        try FileManager.default.createDirectory(at: archiveUrl.appendingPathComponent("inbox"), withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: archiveUrl.appendingPathComponent("test"), withIntermediateDirectories: true, attributes: nil)

        let type = PathManager.ArchivePathType.local(Self.tempFolder.appendingPathComponent("NewArchive"))

        let newArchiveUrl = try type.getArchiveUrl()

        try FileManager.default.createFolderIfNotExists(newArchiveUrl)

        try PathManager.shared.setArchiveUrl(with: type)

        let urls = try FileManager.default.contentsOfDirectory(at: newArchiveUrl, includingPropertiesForKeys: nil, options: [])
        print(urls)
        #expect(urls.contains(where: { $0.lastPathComponent == "untagged" }))
        #expect(urls.contains(where: { $0.lastPathComponent == "2020" }))
        #expect(urls.contains(where: { $0.lastPathComponent == "2019" }))
        #expect(urls.contains(where: { $0.lastPathComponent == "2018" }))

        #expect(!urls.contains(where: { $0.lastPathComponent == "inbox" }))
        #expect(!urls.contains(where: { $0.lastPathComponent == "test" }))
    }
    #endif
}
