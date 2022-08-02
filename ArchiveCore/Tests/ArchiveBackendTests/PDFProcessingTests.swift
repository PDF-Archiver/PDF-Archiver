//
//  PDFProcessingTests.swift
//  
//
//  Created by Julian Kahnert on 01.12.20.
//
// swiftlint:disable force_unwrapping

@testable import ArchiveBackend
import Foundation
import PDFKit
import XCTest

final class PDFProcessingTests: XCTestCase {
    private static let tempFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    private static let referenceDocument = PDFDocument(url: Bundle.billPDFUrl)!

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
                                      tempImagePath: Self.tempFolder) { progress in
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

        assertEqualPDFDocuments(left: document, right: inputDocument)
    }

    func testPNGInput() throws {
        let uuid = UUID()
        let exampleUrl = Self.tempFolder.appendingPathComponent(uuid.uuidString).appendingPathExtension("png")
        try FileManager.default.copyItem(at: Bundle.billPNGUrl, to: exampleUrl)

        let expectation = XCTestExpectation(description: "Document processing completed.")
        let operation = PDFProcessing(of: .images(uuid),
                                      destinationFolder: Self.tempFolder,
                                      tempImagePath: Self.tempFolder) { progress in
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

        assertEqualPDFDocuments(left: document, right: Self.referenceDocument)

        XCTAssertEqual(document.pageCount, 1)
        let creatorAttribute = try XCTUnwrap(document.documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String)
        XCTAssert(creatorAttribute.starts(with: "PDF Archiver"))
        let content = try XCTUnwrap(document.string)
        XCTAssertFalse(content.isEmpty)
        XCTAssert(content.contains("TOM TAILOR"))
        XCTAssert(content.contains("Oldenburg"))
        XCTAssert(content.contains("Vielen Dank"))
        XCTAssert(content.contains("Nachlassbetrag"))
        XCTAssert(content.contains("Mitglied werden"))
    }

    func testJPGInput() throws {
        let uuid = UUID()
        let exampleUrl = Self.tempFolder.appendingPathComponent(uuid.uuidString).appendingPathExtension("jpg")
        try FileManager.default.copyItem(at: Bundle.billJPGGUrl, to: exampleUrl)

        let expectation = XCTestExpectation(description: "Document processing completed.")
        let operation = PDFProcessing(of: .images(uuid),
                                      destinationFolder: Self.tempFolder,
                                      tempImagePath: Self.tempFolder) { progress in
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

        assertEqualPDFDocuments(left: document, right: Self.referenceDocument)

        XCTAssertEqual(document.pageCount, 1)
        let creatorAttribute = try XCTUnwrap(document.documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String)
        XCTAssert(creatorAttribute.starts(with: "PDF Archiver"))
        let content = try XCTUnwrap(document.string)
        XCTAssertFalse(content.isEmpty)
        XCTAssert(content.contains("TOM TAILOR"))
        XCTAssert(content.contains("Oldenburg"))
        XCTAssert(content.contains("Vielen Dank"))
        XCTAssert(content.contains("Nachlassbetrag"))
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
                                      tempImagePath: Self.tempFolder) { progress in
            print("current progress \(progress)")
        }
        operation.completionBlock = {

            XCTAssertNil(operation.error)
            expectation.fulfill()
        }
        queue.addOperation(operation)

        wait(for: [expectation], timeout: 120.0)

        let outputUrl = try XCTUnwrap(operation.outputUrl)
        let document = try XCTUnwrap(PDFDocument(url: outputUrl))

        XCTAssertEqual(document.pageCount, 3)
        let creatorAttribute = try XCTUnwrap(document.documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String)
        XCTAssert(creatorAttribute.starts(with: "PDF Archiver"))
        let content = try XCTUnwrap(document.string)
        XCTAssertFalse(content.isEmpty)
        XCTAssert(content.contains("TOM TAILOR"))
        XCTAssert(content.contains("Oldenburg"))
        XCTAssert(content.contains("Vielen Dank"))
        XCTAssert(content.contains("Nachlassbetrag"))
        XCTAssert(content.contains("Mitglied werden"))
    }
}
