//
//  OpenDocumentIntent.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 19.03.26.
//

import AppIntents
import Shared

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Opens a specific document in PDF Archiver from Shortcuts or Siri.
struct OpenDocument: AppIntent {
    static let title: LocalizedStringResource = "Open Document"
    static let description = IntentDescription("Displays a document in PDF Archiver.")
    static let openAppWhenRun: Bool = true

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$document)")
    }

    @IntentParameter(title: "Document", description: "The document to open.")
    var document: DocumentEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        let url = DeepLink.documentURL(for: document.id)
        #if os(iOS)
        await UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
        return .result()
    }
}
