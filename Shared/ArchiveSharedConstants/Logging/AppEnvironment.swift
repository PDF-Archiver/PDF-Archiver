//
//  AppEnvironment.swift
//  
//
//  Created by Julian Kahnert on 20.10.20.
//

import Foundation

public enum AppEnvironment: String, Codable {
    case develop
    case testflight
    case production
}

public extension AppEnvironment {

    static func get() -> AppEnvironment {
        // return early, if we have a debug build
        #if DEBUG
        return .develop
        #else
        // source from: https://stackoverflow.com/a/38984554
        if let url = Bundle.main.appStoreReceiptURL {
            if url.path.contains("CoreSimulator") {
                return .develop
            } else if url.lastPathComponent == "sandboxReceipt" {
                return .testflight
            }
        }
        return .production
        #endif
    }

    static func getFullVersion() -> String {
        return "\(getVersion()) (\(getBuildNumber()))"
    }

    static func getVersion() -> String {
        return (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
    }

    static func getBuildNumber() -> Int {
        return Int((Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "0") ?? 0
    }

    static func getModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let machineMirror = Mirror(reflecting: systemInfo.machine)

        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}
