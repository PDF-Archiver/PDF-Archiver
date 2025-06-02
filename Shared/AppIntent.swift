//
//  AppIntent.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 27.05.25.
//

import AppIntents

struct ScanDocument: AppIntent {

    static let title: LocalizedStringResource = "Scan"
    static let description = IntentDescription("Scan document and add it to the archive.")
    static let openAppWhenRun: Bool = true

    @Dependency
    private var navigationModel: NavigationModel

    @MainActor
    func perform() async throws -> some IntentResult {

        #if !os(macOS)
        navigationModel.shareNextDocument = false
        navigationModel.lastProcessedDocumentUrl = nil
        #endif
        navigationModel.showScan()

        return .result()
    }
}

struct ScanAndShareDocument: AppIntent {

    static let title: LocalizedStringResource = "Scan & Share"
    static let description = IntentDescription("Scan & share document and add it to the archive.")
    static let openAppWhenRun: Bool = true

    @Dependency
    private var navigationModel: NavigationModel

    @MainActor
    func perform() async throws -> some IntentResult {

        #if !os(macOS)
        navigationModel.shareNextDocument = true
        navigationModel.lastProcessedDocumentUrl = nil
        #endif
        navigationModel.showScan()

        return .result()
    }
}
