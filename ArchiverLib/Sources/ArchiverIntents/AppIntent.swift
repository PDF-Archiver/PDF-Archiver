//
//  AppIntent.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 27.05.25.
//

import AppIntents
import Shared

public protocol IntentNavigation: Sendable {
    func open(link: DeepLink)
}

public struct ScanDocument: AppIntent {

    public static let title: LocalizedStringResource = "Scan"
    public static let description = IntentDescription("Scan document and add it to the archive.")
    public static let openAppWhenRun: Bool = true

    @Dependency
    private var navigationModel: IntentNavigation

    public init() {
    }

    @MainActor
    public func perform() async throws -> some IntentResult {

        navigationModel.open(link: .scan)

        return .result()
    }
}

public struct ScanAndShareDocument: AppIntent {

    public static let title: LocalizedStringResource = "Scan & Share"
    public static let description = IntentDescription("Scan & share document and add it to the archive.")
    public static let openAppWhenRun: Bool = true

    @Dependency
    private var navigationModel: IntentNavigation

    public init() {
    }

    @MainActor
    public func perform() async throws -> some IntentResult {

        navigationModel.open(link: .scanAndShare)

        return .result()
    }
}
