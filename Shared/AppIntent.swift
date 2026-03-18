//
//  AppIntent.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 27.05.25.
//

import AppIntents
import Shared

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/**
 AppIntents in SPM are currently not supported, so we move them here
 https://stackoverflow.com/a/76976224
 */

public struct ScanDocument: AppIntent {

    public static let title: LocalizedStringResource = "Scan"
    public static let description = IntentDescription("Scan document and add it to the archive.")
    public static let openAppWhenRun: Bool = true

    public init() {
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        #if os(iOS)
        await UIApplication.shared.open(DeepLink.scan.url)
        #elseif os(macOS)
        NSWorkspace.shared.open(DeepLink.scan.url)
        #endif
        return .result()
    }
}

public struct ScanAndShareDocument: AppIntent {

    public static let title: LocalizedStringResource = "Scan & Share"
    public static let description = IntentDescription("Scan & share document and add it to the archive.")
    public static let openAppWhenRun: Bool = true

    public init() {
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        #if os(iOS)
        await UIApplication.shared.open(DeepLink.scanAndShare.url)
        #elseif os(macOS)
        NSWorkspace.shared.open(DeepLink.scanAndShare.url)
        #endif
        return .result()
    }
}
