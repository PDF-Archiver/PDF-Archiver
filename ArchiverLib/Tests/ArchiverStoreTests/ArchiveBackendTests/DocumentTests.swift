//
//  DocumentTests.swift
//  ArchiveLib Tests
//
//  Created by Julian Kahnert on 30.11.18.
//

import ArchiverModels
import Foundation
import Shared
import Testing

@testable import ArchiverStore

@MainActor
struct DocumentTests {

    let tag1 = "tag1"
    let tag2 = "tag2"

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

    @Test
    func testDocumentRenaming() throws {

        // setup
        let date = try #require(dateFormatter.date(from: "2010-05-12"))

        // calculate
        let renameOutput = Document.createFilename(date: date, specification: "example-description", tags: Set([tag1, tag2]))

        // assert
        #expect(renameOutput == "2010-05-12--example-description__tag1_tag2.pdf")
    }

    @Test
    func testDocumentRenamingWithSpaceInDescriptionSlugify() throws {

        // setup
        let date = try #require(dateFormatter.date(from: "2010-05-12"))

        let renameOutput = Document.createFilename(date: date, specification: "this-is-a-test", tags: Set([tag1]))

        // assert
        #expect(renameOutput == "2010-05-12--this-is-a-test__tag1.pdf")
    }

    @Test
    func testDocumentRenamingWithFullFilename() throws {

        // setup
        let date = try #require(dateFormatter.date(from: "2010-05-12"))

        // calculate
        let renameOutput = Document.createFilename(date: date, specification: "example-description", tags: Set([tag1, tag2]))

        // assert
        #expect(renameOutput == "2010-05-12--example-description__tag1_tag2.pdf")
    }

    @Test
    func testDocumentRenamingWithNoTags() {

        // setup
        let filename = "scan1.pdf"

        // calculate
        let result = Document.parseFilename(filename)

        // assert
        #expect(result.date == nil)
        #expect(result.specification == nil)
        #expect(result.tagNames == nil)
    }

    @Test
    func testDocumentRenamingWithNoSpecification() {

        // setup
        let filename = "scan1__tag1_tag2.pdf"

        // calculate
        let result = Document.parseFilename(filename)

        // assert
        #expect(result.date == nil)
        #expect(result.specification == nil)
        #expect(result.tagNames == ["tag1", "tag2"])
    }

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
    func testDocumentRenamingPath() throws {

        // setup
        let date = try #require(dateFormatter.date(from: "2010-05-12"))
        let specification = "testing-test-description"
        let tags = Set([tag1, tag2])

        // calculate
        let filename = Document.createFilename(date: date, specification: specification, tags: tags)

        // assert
        #expect(filename == "2010-05-12--testing-test-description__tag1_tag2.pdf")
    }
}
