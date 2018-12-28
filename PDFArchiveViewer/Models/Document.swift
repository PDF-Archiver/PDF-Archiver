//
//  Document.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 22.08.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import Foundation
import os.log

extension Document {

    func download() {
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: path)
            downloadStatus = .downloading(percentDownloaded: 0)
        } catch {
            os_log("%s", log: self.log, type: .debug, error.localizedDescription)
        }
    }
}
