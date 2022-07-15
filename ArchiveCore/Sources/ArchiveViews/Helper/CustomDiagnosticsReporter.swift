//
//  CustomDiagnosticsReporter.swift
//  
//
//  Created by Julian Kahnert on 07.11.20.
//

import Diagnostics
import Foundation

struct CustomDiagnosticsReporter: DiagnosticsReporting {
    func report() -> DiagnosticsChapter {
        let documents = ArchiveStore.shared.documents
        let taggedCount = documents
            .filter { $0.taggingStatus == .tagged }
            .count
        let untaggedCount = documents.count - taggedCount

        let diagnostics: [String: String] = [
            "Environment": AppEnvironment.get().rawValue,
            "Version": AppEnvironment.getFullVersion(),
            "Number of tagged Documents": String(taggedCount),
            "Number of untagged Documents": String(untaggedCount)
        ]
        return DiagnosticsChapter(title: "App Environment", diagnostics: diagnostics)
    }
}
