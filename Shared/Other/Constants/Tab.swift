//
//  Tab.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 28.08.20.
//

import Combine
import SwiftUI

enum Tab: String, CaseIterable, Identifiable, Hashable, Equatable {
    case scan, tag, archive
    #if !os(macOS)
    case more
    #endif

    var id: String { rawValue }
    var name: LocalizedStringKey {
        if self == .scan {
            #if os(macOS)
            return "Import"
            #else
            return "Scan"
            #endif
        } else {
            return LocalizedStringKey(rawValue.capitalized)
        }
    }
    var iconName: String {
        switch self {
            case .scan:
                return "doc.text.viewfinder"
            case .tag:
                return "tag"
            case .archive:
                return "archivebox"
            #if !os(macOS)
            case .more:
                return "ellipsis"
            #endif
        }
    }
}
