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
        let diagnostics: [String: String] = [
            "Environment": AppEnvironment.get().rawValue,
            "Version": AppEnvironment.getFullVersion(),
        ]
        return DiagnosticsChapter(title: "App Environment", diagnostics: diagnostics)
    }
}
