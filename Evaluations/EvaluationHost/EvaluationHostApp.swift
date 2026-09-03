//
//  EvaluationHostApp.swift
//  EvaluationHost
//

import SwiftUI

/// Test host for the evaluations, and nothing else.
///
/// Entitlements belong to the process, not to a loadable bundle: run hostless,
/// the evaluations would execute inside Apple's `xctest` and Private Cloud
/// Compute would trap on the first request. Hosted, they run in this app.
@main
struct EvaluationHostApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Hosts the content extraction evaluations.")
                .padding()
        }
    }
}
