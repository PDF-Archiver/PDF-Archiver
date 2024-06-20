//
//  ProcessInfo.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 20.06.24.
//

#if DEBUG
import Foundation

extension ProcessInfo {
    var isSwiftUIPreview: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
#endif
