//
//  Logging.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 23.08.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation
import os.log

protocol Logging {
    var log: OSLog { get }
}

extension Logging {
    internal var log: OSLog {
        return OSLog(subsystem: Bundle.main.bundleIdentifier!,
                     category: String(describing: type(of: self)))
    }
}
