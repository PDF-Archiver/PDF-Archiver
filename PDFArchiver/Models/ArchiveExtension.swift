//
//  Archive.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 07.07.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import Foundation
import OrderedSet
import os.log
import Quartz

//protocol ArchiveDelegate: AnyObject {
//    func moveArchivedDocuments(from oldArchivePath: URL, to newArchivePath: URL)
//    func updateDocumentsAndTags()
//}

//class Archive: ArchiveDelegate, Logging {
//    var test = OrderedSet<Tag>()
//    var documents = [Document]()
//    weak var preferencesDelegate: PreferencesDelegate?
//    weak var dataModelTagsDelegate: DataModelTagsDelegate?
//
//    func moveArchivedDocuments(from oldArchivePath: URL, to newArchivePath: URL) {
//        if oldArchivePath == newArchivePath {
//            return
//        }
//
//        self.preferencesDelegate?.accessSecurityScope {
//
//            let fileManager = FileManager.default
//            guard let documentsToBeMoved = fileManager.enumerator(at: oldArchivePath,
//                                                                  includingPropertiesForKeys: nil,
//                                                                  options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
//                                                                  errorHandler: nil) else { return }
//
//            for folder in documentsToBeMoved {
//                guard let folderPath = folder as? URL else { continue }
//                try? fileManager.moveItem(at: folderPath,
//                                          to: newArchivePath.appendingPathComponent(folderPath.lastPathComponent))
//            }
//        }
//    }
//

//

//
//    func convertToPDF(from inPath: URL, to outPath: URL) {
//        // Create an empty PDF document
//        let pdfDocument = PDFDocument()
//
//        // Create a PDF page instance from the image
//        let image = NSImage(byReferencing: inPath)
//        guard let pdfPage = PDFPage(image: image) else { fatalError("No PDF page found.") }
//
//        // Insert the PDF page into your document
//        pdfDocument.insert(pdfPage, at: 0)
//
//        // save the pdf document
//        self.preferencesDelegate?.accessSecurityScope {
//            pdfDocument.write(to: outPath)
//
//            // trash old pdf
//            let fileManager = FileManager.default
//            do {
//                try fileManager.trashItem(at: inPath, resultingItemURL: nil)
//            } catch let error {
//                os_log("Can not trash file: %@", log: self.log, type: .debug, error.localizedDescription)
//            }
//        }
//    }
//}
