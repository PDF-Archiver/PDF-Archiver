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

final class PDFProcessingTests: XCTestCase {
    static let tempFolder = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString)
    
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        queue.name = "TEST.ImageConverter.workerQueue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        queue.cancelAllOperations()
        
        try FileManager.default.createDirectory(at: Self.tempFolder, withIntermediateDirectories: true, attributes: nil)
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        
        queue.cancelAllOperations()
        try FileManager.default.removeItem(at: Self.tempFolder)
    }
    
    func testPDFInput() throws {
        let exampleUrl = Self.tempFolder.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        try FileManager.default.copyItem(at: Bundle.longTextPDFUrl, to: exampleUrl)
        let inputDocument = try XCTUnwrap(PDFDocument(url: exampleUrl))
        
        let expectation = XCTestExpectation(description: "Document processing completed.")
        let operation = PDFProcessing(of: .pdf(exampleUrl),
                                      destinationFolder: Self.tempFolder,
                                      tempImagePath: Self.tempFolder,
                                      archiveTags: Set<String>()) { progress in
            print("current progress \(progress)")
        }
        operation.completionBlock = {
            
            XCTAssertNil(operation.error)
            expectation.fulfill()
        }
        queue.addOperation(operation)
        
        wait(for: [expectation], timeout: 100.0)
        
        let outputUrl = try XCTUnwrap(operation.outputUrl)
        let document = try XCTUnwrap(PDFDocument(url: outputUrl))
        
        XCTAssertEqual(document.pageCount, inputDocument.pageCount)
        XCTAssertEqual(document.string, inputDocument.string)
    }
    
    func testPNGInput() throws {
        let uuid = UUID()
        let exampleUrl = Self.tempFolder.appendingPathComponent(uuid.uuidString).appendingPathExtension("png")
        try FileManager.default.copyItem(at: Bundle.billPNGUrl, to: exampleUrl)

        let expectation = XCTestExpectation(description: "Document processing completed.")
        let operation = PDFProcessing(of: .images(uuid),
                                      destinationFolder: Self.tempFolder,
                                      tempImagePath: Self.tempFolder,
                                      archiveTags: Set<String>()) { progress in
            print("current progress \(progress)")
        }
        operation.completionBlock = {
            
            XCTAssertNil(operation.error)
            expectation.fulfill()
        }
        queue.addOperation(operation)
        
        wait(for: [expectation], timeout: 20.0)
        
        let outputUrl = try XCTUnwrap(operation.outputUrl)
        let document = try XCTUnwrap(PDFDocument(url: outputUrl))
        
        XCTAssertEqual(document.pageCount, 1)
        let content = try XCTUnwrap(document.string)
        XCTAssertFalse(content.isEmpty)
        XCTAssert(content.contains("TOM TAILOR"))
        XCTAssert(content.contains("Oldenburg"))
        XCTAssert(content.contains("Vielen Dank"))
        XCTAssert(content.contains("Mitglied werden"))
    }
    
    func testJPGInput() throws {
        let uuid = UUID()
        let exampleUrl = Self.tempFolder.appendingPathComponent(uuid.uuidString).appendingPathExtension("jpg")
        try FileManager.default.copyItem(at: Bundle.billJPGGUrl, to: exampleUrl)

        let expectation = XCTestExpectation(description: "Document processing completed.")
        let operation = PDFProcessing(of: .images(uuid),
                                      destinationFolder: Self.tempFolder,
                                      tempImagePath: Self.tempFolder,
                                      archiveTags: Set<String>()) { progress in
            print("current progress \(progress)")
        }
        operation.completionBlock = {
            
            XCTAssertNil(operation.error)
            expectation.fulfill()
        }
        queue.addOperation(operation)
        
        wait(for: [expectation], timeout: 20.0)
        
        let outputUrl = try XCTUnwrap(operation.outputUrl)
        let document = try XCTUnwrap(PDFDocument(url: outputUrl))
        
        XCTAssertEqual(document.pageCount, 1)
        let content = try XCTUnwrap(document.string)
        XCTAssertFalse(content.isEmpty)
        XCTAssert(content.contains("TOM TAILOR"))
        XCTAssert(content.contains("Oldenburg"))
        XCTAssert(content.contains("Vielen Dank"))
        XCTAssert(content.contains("Mitglied werden"))
    }
    
    func testJPGMultiplePages() throws {
        let uuid = UUID()
        try FileManager.default.copyItem(at: Bundle.billJPGGUrl, to: Self.tempFolder.appendingPathComponent(uuid.uuidString + "-1").appendingPathExtension("jpg"))
        try FileManager.default.copyItem(at: Bundle.billJPGGUrl, to: Self.tempFolder.appendingPathComponent(uuid.uuidString + "-2").appendingPathExtension("jpg"))
        try FileManager.default.copyItem(at: Bundle.billJPGGUrl, to: Self.tempFolder.appendingPathComponent(uuid.uuidString + "-3").appendingPathExtension("jpg"))

        let expectation = XCTestExpectation(description: "Document processing completed.")
        let operation = PDFProcessing(of: .images(uuid),
                                      destinationFolder: Self.tempFolder,
                                      tempImagePath: Self.tempFolder,
                                      archiveTags: Set<String>()) { progress in
            print("current progress \(progress)")
        }
        operation.completionBlock = {
            
            XCTAssertNil(operation.error)
            expectation.fulfill()
        }
        queue.addOperation(operation)
        
        wait(for: [expectation], timeout: 60.0)
        
        let outputUrl = try XCTUnwrap(operation.outputUrl)
        let document = try XCTUnwrap(PDFDocument(url: outputUrl))
        
        XCTAssertEqual(document.pageCount, 3)
        let content = try XCTUnwrap(document.string)
        XCTAssertFalse(content.isEmpty)
        XCTAssert(content.contains("TOM TAILOR"))
        XCTAssert(content.contains("Oldenburg"))
        XCTAssert(content.contains("Vielen Dank"))
        XCTAssert(content.contains("Mitglied werden"))
    }
}
