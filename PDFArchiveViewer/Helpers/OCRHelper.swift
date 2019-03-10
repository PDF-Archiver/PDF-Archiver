//
//  OCRHelper.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 10.03.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation
import TesseractOCR

enum OCRHelper {

    static func createOCR(_ image: UIImage) -> String {

        var content: String?

        // tessdata source: https://github.com/tesseract-ocr/tessdata/tree/3.04.00
        if let tesseract = G8Tesseract(language: "deu+eng") {
            // could not find any german "tessdata cube" files, therefore we use "tesseractOnly" mode
            tesseract.engineMode = .tesseractOnly
            tesseract.pageSegmentationMode = .auto
            tesseract.image = image.g8_blackAndWhite()
            tesseract.recognize()
            content = tesseract.recognizedText
        }

        return content ?? ""
    }
}
