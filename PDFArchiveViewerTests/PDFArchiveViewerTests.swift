//
//  PDFArchiveViewerTests.swift
//  PDFArchiveViewerTests
//
//  Created by Julian Kahnert on 23.10.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import ArchiveLib
@testable import PDFArchiveViewer
import PDFKit
import XCTest

class PDFArchiveViewerTests: XCTestCase {

    func testOCRContentParsing() {

        guard let image = UIImage(named: "test-ocr-data.png") else { return XCTFail("Could not find image!") }

        // get OCR content
        let content = OCRHelper.createOCR(image)

        // parse the date
        let parsedDate = DateParser.parse(content)

        // parse the tags
        let newTags = TagParser.parse(content)

        print(content)
        XCTAssertFalse(content.isEmpty)
        XCTAssertFalse(newTags.isEmpty)
        XCTAssertNotNil(parsedDate)
    }
}
