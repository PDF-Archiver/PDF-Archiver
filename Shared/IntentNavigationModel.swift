//
//  IntentNavigationModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 14.03.26.
//

import AppIntents
import Shared

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

final class IntentNavigationModel: IntentNavigation {
    static let shared = IntentNavigationModel()

    func open(link: DeepLink) {
        let url = link.url
        #if os(iOS)
        Task { @MainActor in
            await UIApplication.shared.open(url)
        }
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
}
