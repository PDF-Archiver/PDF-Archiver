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
import UIKit

public struct ImageConverter: Logging {

    public static func process(_ image: UIImage, saveAt path: URL) {

        // convert image to pdf
        let pdfDocument = convertToPDF(image)

        // generate filename by analysing the image
        let filename = getFilenameFrom(image)
        let filepath = path.appendingPathComponent(filename)

        // save PDF
        savePDF(pdfDocument, at: filepath)
    }

    private static func convertToPDF(_ image: UIImage) -> PDFDocument {
        // Create an empty PDF document
        let pdfDocument = PDFDocument()

        // Create a PDF page instance from the image
        guard let pdfPage = PDFPage(image: image) else { fatalError("No PDF page found.") }

        // Insert the PDF page into your document
        pdfDocument.insert(pdfPage, at: 0)

        return pdfDocument
    }

    static func getFilenameFrom(_ image: UIImage) -> String {

        // get OCR content
        let content = OCRHelper.createOCR(image)

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

    private static func savePDF(_ pdfDocument: PDFDocument, at path: URL) {

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
