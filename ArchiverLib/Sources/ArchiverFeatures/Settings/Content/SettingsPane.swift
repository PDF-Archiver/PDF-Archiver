//
//  SettingsPane.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.09.26.
//

#if os(macOS)
import SwiftUI

/// One Settings pane per topic, in sidebar order. `rawValue` is persisted
/// (`SharedKey.settingsPane`): the spellings are a stored format and must not be renamed.
enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
    case general, storage, appleIntelligence, searchIndex, advanced, premium, about

    /// Falls back to `.general` when the persisted string does not decode.
    init(persisted rawValue: String) {
        self = SettingsPane(rawValue: rawValue) ?? .general
    }

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .general: return "General"
        case .storage: return "Storage"
        case .appleIntelligence: return "Apple Intelligence"
        case .searchIndex: return "Search Index"
        case .advanced: return "Advanced"
        case .premium: return "Premium"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gear"
        case .storage: return "externaldrive"
        case .appleIntelligence: return "apple.intelligence"
        case .searchIndex: return "magnifyingglass.circle"
        case .advanced: return "gearshape.2"
        case .premium: return "star.hexagon"
        case .about: return "info.circle"
        }
    }
}
#endif
