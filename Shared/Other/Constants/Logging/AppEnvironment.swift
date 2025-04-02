//
//  AppEnvironment.swift
//  
//
//  Created by Julian Kahnert on 20.10.20.
//

import Foundation

enum AppEnvironment {
    static func getFullVersion() -> String {
        return "\(getVersion()) (\(getBuildNumber()))"
    }

    private static func getVersion() -> String {
        return (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
    }

    private static func getBuildNumber() -> Int {
        return Int((Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "0") ?? 0
    }
}
