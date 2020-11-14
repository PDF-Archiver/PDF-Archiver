//
//  Tab.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 28.08.20.
//

import Combine
import SwiftUI

public enum Tab: String, CaseIterable, Identifiable, Hashable, Equatable {
    case scan, tag, archive, more

    public var id: String { rawValue }
    public var name: String { rawValue.capitalized }
    public var iconName: String {
        switch self {
            case .scan:
                return "doc.text.viewfinder"
            case .tag:
                return "tag"
            case .archive:
                return "archivebox"
            case .more:
                return "ellipsis"
        }
    }
}
