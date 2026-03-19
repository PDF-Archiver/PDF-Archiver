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

    /// Constructs the deep link URL for a specific document.
    public static func documentURL(for id: Int) -> URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: "pdfarchiver://documents/\(id)")!
    }

    /// Extracts the document ID from a document deep link URL, returning nil for non-document URLs.
    public static func documentID(from url: URL) -> Int? {
        guard url.scheme == "pdfarchiver",
              url.host == "documents",
              let idString = url.pathComponents.dropFirst().first,
              let id = Int(idString) else { return nil }
        return id
    }
}
