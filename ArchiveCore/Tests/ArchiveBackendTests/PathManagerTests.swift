//
//  PDFProcessingTests.swift
//  
//
//  Created by Julian Kahnert on 01.12.20.
//

@testable import ArchiveBackend
import Foundation
import XCTest
import PDFKit

final class PathManagerTests: XCTestCase {
    static let tempFolder = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString)
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        try FileManager.default.createDirectory(at: Self.tempFolder, withIntermediateDirectories: true, attributes: nil)
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        try FileManager.default.removeItem(at: Self.tempFolder)
    }

    #if os(macOS)
    func testArchiveChangeMacOS() throws {
        let currentArchiveFolder = Self.tempFolder.appendingPathComponent("CurrentArchive")
        UserDefaults.appGroup.archivePathType = .local(currentArchiveFolder)
        
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
        XCTAssert(urls.contains(where: { $0.lastPathComponent == "untagged" }))
        XCTAssert(urls.contains(where: { $0.lastPathComponent == "2020" }))
        XCTAssert(urls.contains(where: { $0.lastPathComponent == "2019" }))
        XCTAssert(urls.contains(where: { $0.lastPathComponent == "2018" }))
        
        XCTAssertFalse(urls.contains(where: { $0.lastPathComponent == "inbox" }))
        XCTAssertFalse(urls.contains(where: { $0.lastPathComponent == "test" }))
    }
    #endif
    
    #if !os(macOS)
    func testPDFInput() throws {
        UserDefaults.appGroup.archivePathType = .appContainer
        
        let archiveUrl = try PathManager.shared.getArchiveUrl()
        
        // folders that should be copied
        try FileManager.default.createDirectory(at: archiveUrl.appendingPathComponent("untagged"), withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: archiveUrl.appendingPathComponent("2020"), withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: archiveUrl.appendingPathComponent("2019"), withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: archiveUrl.appendingPathComponent("2018"), withIntermediateDirectories: true, attributes: nil)
        // folders that should not be copied
        try FileManager.default.createDirectory(at: archiveUrl.appendingPathComponent("inbox"), withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: archiveUrl.appendingPathComponent("test"), withIntermediateDirectories: true, attributes: nil)
        
        let type = PathManager.ArchivePathType.iCloudDrive

        do {
            let newArchiveUrl = try type.getArchiveUrl()
            
            try FileManager.default.createFolderIfNotExists(newArchiveUrl)
            
            try PathManager.shared.setArchiveUrl(with: type)
            
            let urls = try FileManager.default.contentsOfDirectory(at: newArchiveUrl, includingPropertiesForKeys: nil, options: [])
            XCTAssert(urls.contains(where: { $0.lastPathComponent == "untagged" }))
            XCTAssert(urls.contains(where: { $0.lastPathComponent == "2020" }))
            XCTAssert(urls.contains(where: { $0.lastPathComponent == "2019" }))
            XCTAssert(urls.contains(where: { $0.lastPathComponent == "2018" }))
            
            XCTAssertFalse(urls.contains(where: { $0.lastPathComponent == "inbox" }))
            XCTAssertFalse(urls.contains(where: { $0.lastPathComponent == "test" }))
        } catch {
            throw XCTSkip()
        }
    }
    #endif
}
