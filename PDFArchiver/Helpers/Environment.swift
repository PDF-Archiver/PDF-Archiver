//
//  Environment.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 16.07.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation

enum Environment: String {
    case develop
    case testflight
    case production

    static func get() -> Environment {
        // return early, if we have a debug build
        #if DEBUG
        return .develop
        #endif

        // source from: https://stackoverflow.com/a/38984554
        if let url = Bundle.main.appStoreReceiptURL {
            if url.path.contains("CoreSimulator") {
                return .develop
            } else if url.lastPathComponent == "sandboxReceipt" {
                return .testflight
            }
        }
        return .production
    }
}
