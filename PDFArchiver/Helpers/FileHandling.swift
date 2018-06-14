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

func getPDFs(url: URL) -> [URL] {
    // get URL (file or folder) and return paths of the file or all PDF documents in this folder
    let fileManager = FileManager.default
    if fileManager.isDirectory(url: url) ?? false {
        // folder found
        let enumerator = fileManager.enumerator(atPath: url.path)!
        var pdfURLs = [URL]()
        for element in enumerator {
            if let filename = element as? String {
                var pdfUrl: URL
                let completeDocumentPath = URL(fileURLWithPath: url.path).appendingPathComponent(filename)

                if filename.lowercased().hasSuffix("pdf") {
                    // add PDF
                    pdfUrl = URL(fileURLWithPath: url.path).appendingPathComponent(filename)

                } else if let fileTypeIdentifier = completeDocumentPath.typeIdentifier,
                    NSImage.imageTypes.contains(fileTypeIdentifier) {
                    // convert picture/supported file to PDF
                    pdfUrl = convertToPDF(completeDocumentPath)

                } else {
                    // skip the unsupported filetype
                    continue
                }

                pdfURLs.append(pdfUrl)
            }
        }
        return pdfURLs

    } else if fileManager.isReadableFile(atPath: url.path) && url.pathExtension.lowercased() == "pdf" {
        // pdf file found
        return [url]

    } else if let identifier = url.typeIdentifier,
        fileManager.isReadableFile(atPath: url.path) && NSImage.imageTypes.contains(identifier) {
        // picture file found
        let pdfUrl = convertToPDF(url)
        return [pdfUrl]

    } else {
        // no file or directory found
        return []
    }
}

extension FileManager {
    func isDirectory(url: URL) -> Bool? {
        var isDir: ObjCBool = ObjCBool(false)
        if fileExists(atPath: url.path, isDirectory: &isDir) {
            return isDir.boolValue
        } else {
            return nil
        }
    }
}
