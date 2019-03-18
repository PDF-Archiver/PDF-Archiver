//
//  ImageConverter.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 05.03.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import Foundation
import os.log
import PDFKit
import SwiftyTesseract
import UIKit

public struct ImageConverter: Logging {

    private static let languages: [RecognitionLanguage] = [.german, .english, .italian, .french, .swedish, .russian]
//    private static let languages: [RecognitionLanguage] = {
//        var langs: [RecognitionLanguage] = [.german, .english]
//
//        if Locale.current.identifier.starts(with: "it") {
//            langs.append(.italian)
//        } else if Locale.current.identifier.starts(with: "fr") {
//            langs.append(.french)
//        } else if Locale.current.identifier.starts(with: "sv") {
//            langs.append(.swedish)
//        } else if Locale.current.identifier.starts(with: "ru") {
//            langs.append(.russian)
//        }
//        return langs
//    }()

    public static func process(_ images: [UIImage], saveAt path: URL) {

        // convert image to pdf
        let pdfDocument = createPDF(from: images)

        // generate filename by analysing the image
        let filename = getFilename(from: pdfDocument)
        let filepath = path.appendingPathComponent(filename)

        // save PDF document
        save(pdfDocument, at: filepath)
    }

    static func createPDF(from images: [UIImage]) -> PDFDocument {

        let document: PDFDocument

        // try to create a pdf document from
        let swiftyTesseract = SwiftyTesseract(languages: languages, bundle: .main, engineMode: .lstmOnly)
        if let data = try? swiftyTesseract.createPDF(from: images),
            let newDocument = PDFDocument(data: data) {
            document = newDocument

        } else {
            // Create an empty PDF document
            let newDocument = PDFDocument()

            for (index, image) in images.enumerated() {

                // Create a PDF page instance from the image
                guard let pdfPage = PDFPage(image: image) else { continue }

                // Insert the PDF page into your document
                newDocument.insert(pdfPage, at: index)
            }

            document = newDocument
        }

        return document
    }

    static func getFilename(from document: PDFDocument) -> String {

        // get OCR content
        guard let content = document.string else { return "" }

        // parse the date
        let parsedDate = DateParser.parse(content)
        let date = parsedDate?.date ?? Date()

        // parse the tags
        var newTags = TagParser.parse(content)
        if newTags.isEmpty {
            newTags.insert("ocr")
            newTags.insert("scan")
        }

        // get default specification
        let specification = Date().timeIntervalSince1970.description

        return Document.createFilename(date: date, specification: specification, tags: newTags)
    }

    private static func save(_ pdfDocument: PDFDocument, at path: URL) {

        // check if the parent folder exists
        let folder = path.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: folder.path, isDirectory: nil) {
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
            } catch {
                os_log("Directory creation error: %@", log: log, type: .error, error.localizedDescription)
            }
        }

        // save PDF document
        pdfDocument.write(to: path)
    }
}
