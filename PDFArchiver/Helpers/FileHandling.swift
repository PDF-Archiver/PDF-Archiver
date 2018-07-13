//
//  FileHandling.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Quartz
import os.log

func getOpenPanel(_ title: String) -> NSOpenPanel {
    let openPanel = NSOpenPanel()
    openPanel.title = title
    openPanel.showsResizeIndicator = false
    openPanel.showsHiddenFiles = false
    openPanel.canChooseFiles = false
    openPanel.canChooseDirectories = true
    openPanel.allowsMultipleSelection = false
    openPanel.canCreateDirectories = true
    return openPanel
}

func convertToPDF(_ inPath: URL) -> URL {
    // ATTENTION: this function needs access to the filesystem security scope

    // Create an empty PDF document
    let pdfDocument = PDFDocument()

    // Create a PDF page instance from the image
    let image = NSImage(byReferencing: inPath)
    let pdfPage = PDFPage(image: image)

    // Insert the PDF page into your document
    pdfDocument.insert(pdfPage!, at: 0)

    // get the output path and save the pdf document
    var outPath = inPath
    outPath.deletePathExtension()
    outPath = outPath.appendingPathExtension("pdf")
    pdfDocument.write(to: outPath)

    // trash old pdf
    let fileManager = FileManager.default
    do {
        try fileManager.trashItem(at: inPath, resultingItemURL: nil)
    } catch let error {
        let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "convertToPDF")
        os_log("Can not trash file: %@", log: log, type: .debug, error.localizedDescription)
    }

    return outPath
}
