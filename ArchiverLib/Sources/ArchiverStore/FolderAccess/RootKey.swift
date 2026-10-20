//
//  RootKey.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import Foundation
import Shared

/// The logical name a root is stored under.
///
/// Never the root's path: the same file appears as `/private/var/…` and `/var/…`, and the iOS
/// app-container path changes with every app update.
enum RootKey {
    static func of(_ folder: URL) -> String {
        let normalized = folder.normalized()

        if let iCloudUrl = FileManager.default.iCloudDriveURL?.normalized(),
           normalized.path().hasPrefix(iCloudUrl.path()) {
            return "icloud"
        }

        #if os(iOS)
        if normalized.path().hasPrefix(FileManager.default.appContainerURL.normalized().path()) {
            return "appContainer"
        }
        #endif

        return normalized.path()
    }
}
