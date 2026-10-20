//
//  OpenExternalURL.swift
//  ArchiverLib
//

import ComposableArchitecture
import SwiftUI

extension Effect {
    /// Opens `url` outside the app. Release builds on the Mac go through `NSWorkspace`; iOS and
    /// Debug builds through the `openURL` dependency, which is what lets tests observe the URL.
    static func openExternalURL(_ url: URL, with openURL: OpenURLEffect) -> Self {
        #if os(iOS) || DEBUG
        return .run { _ in
            await openURL(url)
        }
        #else
        NSWorkspace.shared.open(url)
        return .none
        #endif
    }
}
