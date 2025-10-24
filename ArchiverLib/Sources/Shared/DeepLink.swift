//
//  DeepLink.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 04.06.25.
//

import AppIntents

public enum DeepLink: String, CaseIterable {
    case scan, scanAndShare
    case tag

    public var url: URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: "pdfarchiver:///widget/\(rawValue)")!
    }
}
