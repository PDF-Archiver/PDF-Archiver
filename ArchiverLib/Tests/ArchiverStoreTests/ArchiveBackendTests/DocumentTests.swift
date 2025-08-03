//
//  DocumentTests.swift
//  ArchiveLib Tests
//
//  Created by Julian Kahnert on 30.11.18.
//

import ArchiverModels
import Foundation
import Testing
import Shared
@testable import ArchiverStore

@MainActor
struct DocumentTests {

    let tag1 = "tag1"
    let tag2 = "tag2"

    let defaultSize = 1024

    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    // MARK: - Test Document.parseFilename

    @Test
    func testFilenameParsing1() {

        // setup
        let path = URL(fileURLWithPath: "~/Downloads/2010-05-12--example-description__tag1_tag2_tag4.pdf")

        // calculate
        let parsingOutput = Document.parseFilename(path.lastPathComponent)

        // assert
        #expect(parsingOutput.date == dateFormatter.date(from: "2010-05-12"))
        #expect(parsingOutput.specification == "example-description")
        #expect(parsingOutput.tagNames == ["tag1", "tag2", "tag4"])
    }

    @Test
    func testFilenameParsing2() {

        // setup
        let path = URL(fileURLWithPath: "~/Downloads/2010-05-12__tag1_tag2_tag4.pdf")

        // calculate
        let parsingOutput = Document.parseFilename(path.lastPathComponent)

        // assert
        #expect(parsingOutput.date == dateFormatter.date(from: "2010-05-12"))
        #expect(parsingOutput.specification == nil)
        #expect(parsingOutput.tagNames == ["tag1", "tag2", "tag4"])
    }

    @Test
    func testFilenameParsing3() {

        // setup
        let path = URL(fileURLWithPath: "~/Downloads/scan 1.pdf")

        // calculate
        let parsingOutput = Document.parseFilename(path.lastPathComponent)

        // assert
        #expect(parsingOutput.date == nil)
        #expect(parsingOutput.specification == nil)
        #expect(parsingOutput.tagNames == nil)
    }

    @Test
    func testFilenameParsing4() {

        // setup
        let path = URL(fileURLWithPath: "~/Downloads/2019-09-02--gfwob abrechnung für 2018__hausgeldabrechung_steuer_wohnung.pdf")

        // calculate
        let parsingOutput = Document.parseFilename(path.lastPathComponent)

        // assert
        #expect(parsingOutput.date == dateFormatter.date(from: "2019-09-02"))
        #expect(parsingOutput.specification == "gfwob abrechnung für 2018")
        #expect(parsingOutput.tagNames == ["hausgeldabrechung", "steuer", "wohnung"])
    }

    // MARK: - Test Document.getRenamingPath

//    @Test
//    func testDocumentRenaming() {
//
//        // setup
//        let path = URL(fileURLWithPath: "~/Downloads/scan1.pdf")
//        let document = Document(path: path, taggingStatus: .untagged, downloadStatus: defaultDownloadStatus, byteSytebyteSize: defaultSize)
//
//        document.date = dateFormatter.date(from: "2010-05-12") ?? Date()
//        document.specification = "example-description"
//        document.tags = Set([tag1, tag2])
//
//        // calculate
//        let renameOutput = try? document.getRenamingPath()
//
//        // assert
//        XCTAssertNoThrow(try document.getRenamingPath())
//        XCTAssertEqual(renameOutput?.foldername, "2010")
//        XCTAssertEqual(renameOutput?.filename, "2010-05-12--example-description__tag1_tag2.pdf")
//    }
//
//    @Test
//    func testDocumentRenamingWithSpaceInDescriptionSlugify() {
//
//        // setup
//        let path = URL(fileURLWithPath: "~/Downloads/Testscan 1.pdf")
//
//        let document = Document(path: path, downloadStatus: defaultDownloadStatus, taggingStatus: .untagged, byteSize: defaultSize)
//        document.specification = "this-is-a-test"
//        document.tags = Set([tag1])
//        document.date = dateFormatter.date(from: "2010-05-12") ?? Date()
//
//        let renameOutput = try? document.getRenamingPath()
//
//        // assert
//        XCTAssertNoThrow(try document.getRenamingPath())
//        XCTAssertEqual(renameOutput?.foldername, "2010")
//        XCTAssertEqual(renameOutput?.filename, "2010-05-12--this-is-a-test__tag1.pdf")
//    }
//
//    @Test
//    func testDocumentRenamingWithFullFilename() {
//
//        // setup
//        let path = URL(fileURLWithPath: "~/Downloads/2010-05-12--example-description__tag1_tag2.pdf")
//        let document = Document(path: path, downloadStatus: defaultDownloadStatus, taggingStatus: .untagged, byteSize: defaultSize)
//
//        // calculate
//        let renameOutput = try? document.getRenamingPath()
//
//        // assert
//        XCTAssertNoThrow(try document.getRenamingPath())
//        XCTAssertEqual(renameOutput?.foldername, "2010")
//        XCTAssertEqual(renameOutput?.filename, "2010-05-12--example-description__tag1_tag2.pdf")
//    }
//
//    @Test
//    func testDocumentRenamingWithNoTags() {
//
//        // setup
//        let path = URL(fileURLWithPath: "~/Downloads/scan1.pdf")
//
//        // calculate
//        let document = Document(path: path, taggingStatus: .untagged, downloadStatus: defaultDownloadStatus, byteSize: defaultSize)
//
//        // assert
//        XCTAssertEqual(document.tags.count, 0)
//        XCTAssertEqual(document.specification, "scan1")
//        XCTAssertThrowsError(try document.getRenamingPath())
//    }
//
//    @Test
//    func testDocumentRenamingWithNoSpecification() {
//
//        // setup
//        let path = URL(fileURLWithPath: "~/Downloads/scan1__tag1_tag2.pdf")
//
//        // calculate
//        let document = Document(path: path, taggingStatus: .untagged, downloadStatus: defaultDownloadStatus, byteSize: defaultSize)
//        document.specification = ""
//
//        // assert
//        XCTAssertEqual(document.tags.count, 2)
//        XCTAssertEqual(document.specification, "")
//        XCTAssertThrowsError(try document.getRenamingPath())
//    }

    // MARK: - Test Hashable, Comparable, CustomStringConvertible

//    @Test
//    func testHashable() {
//
//        // setup
//        let document1 = Document(path: URL(fileURLWithPath: "~/Downloads/2018-05-12--aaa-example-description__tag1_tag2.pdf"), taggingStatus: .tagged, downloadStatus: defaultDownloadStatus, byteSize: defaultSize)
//        let document2 = Document(path: URL(fileURLWithPath: "~/Downloads/2018-05-12--bbb-example-description__tag1_tag2.pdf"), taggingStatus: .tagged, downloadStatus: defaultDownloadStatus, byteSize: defaultSize)
//        let document3 = Document(path: URL(fileURLWithPath: "~/Downloads/2010-05-12--aaa-example-description__tag1_tag2.pdf"), taggingStatus: .untagged, downloadStatus: defaultDownloadStatus, byteSize: defaultSize)
//        let invalidSortDescriptor = NSSortDescriptor(key: "test", ascending: true)
//        let filenameSortDescriptor1 = NSSortDescriptor(key: "filename", ascending: true)
//        let filenameSortDescriptor2 = NSSortDescriptor(key: "filename", ascending: false)
//        let taggingStatusSortDescriptor1 = NSSortDescriptor(key: "taggingStatus", ascending: true)
//        let taggingStatusSortDescriptor2 = NSSortDescriptor(key: "taggingStatus", ascending: false)
//
//        let documents = [document1, document2, document3]
//
//        // calculate
//        guard let sortedDocuments1 = try? sort(documents, by: [filenameSortDescriptor1]) else { XCTFail("Sorting failed!"); return }
//        guard let sortedDocuments2 = try? sort(documents, by: [filenameSortDescriptor2]) else { XCTFail("Sorting failed!"); return }
//        guard let sortedDocuments3 = try? sort(documents, by: [taggingStatusSortDescriptor1, filenameSortDescriptor1]) else { XCTFail("Sorting failed!"); return }
//        guard let sortedDocuments4 = try? sort(documents, by: [taggingStatusSortDescriptor2, filenameSortDescriptor1]) else { XCTFail("Sorting failed!"); return }
//
//        // assert
//        // sort by date
//        XCTAssertTrue(document3 < document1)
//        // sort by filename
//        XCTAssertTrue(document2 < document1)
//        // invalid sort descriptor
//        XCTAssertThrowsError(try sort(documents, by: [invalidSortDescriptor]))
//        // filename sort descriptor ascending
//        XCTAssertEqual(sortedDocuments1[0], document3)
//        XCTAssertEqual(sortedDocuments1[1], document1)
//        XCTAssertEqual(sortedDocuments1[2], document2)
//        // filename sort descriptor descending
//        XCTAssertEqual(sortedDocuments2[0], document2)
//        XCTAssertEqual(sortedDocuments2[1], document1)
//        XCTAssertEqual(sortedDocuments2[2], document3)
//        // tagging status sort descriptor ascending
//        XCTAssertEqual(sortedDocuments3[0], document3)
//        XCTAssertEqual(sortedDocuments3[1], document1)
//        XCTAssertEqual(sortedDocuments3[2], document2)
//        // tagging status sort descriptor ascending
//        XCTAssertEqual(sortedDocuments4[0], document1)
//        XCTAssertEqual(sortedDocuments4[1], document2)
//        XCTAssertEqual(sortedDocuments4[2], document3)
//    }
//
//    @Test
//    func testComparable() {
//
//        // setup
//        let document1 = Document(path: URL(fileURLWithPath: "~/Downloads/2018-05-12--example-description__tag1_tag2.pdf"), taggingStatus: .tagged, downloadStatus: defaultDownloadStatus, byteSize: defaultSize)
//        let document2 = Document(path: URL(fileURLWithPath: "~/Downloads/2018-05-12--example-description__tag1_tag2.pdf"), taggingStatus: .tagged, downloadStatus: defaultDownloadStatus, byteSize: defaultSize)
//
//        document2.specification = "this is a test"
//
//        // assert
//        XCTAssertEqual(document1.id, document2.id)
//        XCTAssertEqual(document1, document2)
//        XCTAssertEqual(document1.hashValue, document2.hashValue)
//    }
//
//    @Test
//    func testComparableWithSameUUID() {
//
//        // setup
//        let document1 = Document(path: URL(fileURLWithPath: "~/Downloads/2018-05-12--example-description__tag1_tag2.pdf"), taggingStatus: .tagged, downloadStatus: defaultDownloadStatus, byteSize: defaultSize)
//        let document2 = Document(path: URL(fileURLWithPath: "~/Downloads/2018-05-12--example-description__tag1_tag2.pdf"), taggingStatus: .tagged, downloadStatus: defaultDownloadStatus, byteSize: defaultSize)
//
//        document2.specification = "this is a test"
//
//        // assert
//        XCTAssertEqual(document1, document2)
//        XCTAssertEqual(document1.hashValue, document2.hashValue)
//    }
//
//    @Test
//    func testSearchable() {
//
//        // setup
//        let path = URL(fileURLWithPath: "~/Downloads/2018-05-12--example-description__tag1_tag2.pdf")
//        let document = Document(path: path, taggingStatus: .tagged, downloadStatus: defaultDownloadStatus, byteSize: defaultSize)
//
//        // assert
//        XCTAssertEqual(document.term, path.lastPathComponent.lowercased().utf8.map { UInt8($0) })
//    }

    // MARK: - Test the whole workflow

    @Test
    func testDocumentNameParsing() throws {

        // setup some of the testing variables
        let path = URL(fileURLWithPath: "~/Downloads/2010-05-12--example-description__tag1_tag2_tag4.pdf")

        // create a basic document
        let (date, specification, tagNames) = Document.parseFilename(path.lastPathComponent)
        let tags = Set(try #require(tagNames))

        // assert
        #expect(specification == "example-description")

        #expect(tags.count == 3)
        #expect(tags.contains(tag1))
        #expect(tags.contains(tag2))
        #expect(date == dateFormatter.date(from: "2010-05-12"))
    }

//    @Test
////    func testDocumentWithEmptyName() {
////
////        // setup
////        let path = URL(fileURLWithPath: "~/Downloads/scan1.pdf")
////
////        // calculate
////        let document = Document(path: path, taggingStatus: .tagged, downloadStatus: defaultDownloadStatus, byteSize: defaultSize)
////
////        // assert
////        XCTAssertNil(document.date)
////    }

    @Test
    func testDocumentDateParsingFormat0() throws {

        // setup
        let path = URL(fileURLWithPath: "~/Downloads/2010-05-12--example-filename__test.pdf")

        // calculate
        let (date, specification, tagNames) = Document.parseFilename(path.lastPathComponent)

        // assert
        let parsedDate = try #require(date)
        let desiredDate = try #require(dateFormatter.date(from: "2010-05-12"))
        #expect(Calendar.current.isDate(parsedDate, inSameDayAs: desiredDate))
        #expect(specification == "example-filename")
        #expect(specification?.localizedCapitalized == "Example-Filename")
        #expect(tagNames == ["test"])
    }
    
    @Test
    func testDocumentDateParsingFormat1() throws {

        // setup
        let path = URL(fileURLWithPath: "~/Downloads/2010-05-12 example filename.pdf")

        // calculate
        let (date, specification, tagNames) = Document.parseFilename(path.lastPathComponent)

        // assert
        let parsedDate = try #require(date)
        let desiredDate = try #require(dateFormatter.date(from: "2010-05-12"))
        #expect(Calendar.current.isDate(parsedDate, inSameDayAs: desiredDate))
        #expect(specification == nil)
        #expect(specification?.localizedCapitalized == nil)
        #expect(tagNames == nil)
    }

    @Test
    func testDocumentDateParsingFormat2() throws {

        // setup
        let path = URL(fileURLWithPath: "~/Downloads/2010_05_12 example filename.pdf")

        // calculate
        let (date, specification, tagNames) = Document.parseFilename(path.lastPathComponent)

        // assert
        let parsedDate = try #require(date)
        let desiredDate = try #require(dateFormatter.date(from: "2010-05-12"))
        #expect(Calendar.current.isDate(parsedDate, inSameDayAs: desiredDate))
        #expect(specification == nil)
        #expect(tagNames == nil)
    }

    @Test
    func testDocumentDateParsingFormat3() throws {

        // setup
        let path = URL(fileURLWithPath: "~/Downloads/20100512 example filename.pdf")

        // calculate
        let (date, specification, tagNames) = Document.parseFilename(path.lastPathComponent)

        // assert
        let parsedDate = try #require(date)
        let desiredDate = try #require(dateFormatter.date(from: "2010-05-12"))
        #expect(Calendar.current.isDate(parsedDate, inSameDayAs: desiredDate))
        #expect(specification == nil)
        #expect(tagNames == nil)
    }

    @Test
    func testDocumentDateParsingFormat4() throws {

        // setup
        let path = URL(fileURLWithPath: "~/Downloads/2010_05_12__15_17.pdf")

        // calculate
        let (date, specification, tagNames) = Document.parseFilename(path.lastPathComponent)
        let tags = Set(try #require(tagNames))

        // assert
        #expect(date == dateFormatter.date(from: "2010-05-12"))
        #expect(specification == nil)
        #expect(tags.contains("15"))
        #expect(tags.contains("17"))
    }

    @Test
    func testDocumentDateParsingScanSnapFormat() {

        // setup
        let path = URL(fileURLWithPath: "~/Downloads/2010_05_12_15_17.pdf")

        // calculate
        let (date, specification, tagNames) = Document.parseFilename(path.lastPathComponent)

        // assert
        #expect(date == dateFormatter.date(from: "2010-05-12"))
        #expect(specification == nil)
        #expect(tagNames == nil)
    }

    @Test
    func testPlaceholder() throws {

        // setup
        let date = try #require(dateFormatter.date(from: "2018-05-12"))
        let document = Document(id: 1,
                                url: URL(fileURLWithPath: "~/Downloads/2018-05-12--\(Constants.documentDescriptionPlaceholder)__\(Constants.documentTagPlaceholder).pdf"),
                                date: date,
                                specification: "",
                                tags: [],
                                isTagged: true,
                                sizeInBytes: 0,
                                downloadStatus: 1)

        // assert - placeholders must not be in the tags or specification
        #expect(document.tags == [])
        #expect(document.specification == "")
    }

    @Test
    func testDocumentRenamingPath() {

        // setup
        let date = dateFormatter.date(from: "2010-05-12") ?? Date()
        let specification = "testing-test-description"
        let tags = Set([tag1, tag2])

        // calculate
        let filename = Document.createFilename(date: date, specification: specification, tags: tags)

        // assert
        #expect(filename == "2010-05-12--testing-test-description__tag1_tag2.pdf")
    }
}
