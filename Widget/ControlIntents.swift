//
//  ControlIntents.swift
//  Widget
//
//  Created by Julian Kahnert on 14.03.26.
//

import AppIntents
import Shared

struct OpenScanControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Scan"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(DeepLink.scan.url))
    }
}

struct OpenTagControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Tag Documents"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(DeepLink.tag.url))
    }
}
