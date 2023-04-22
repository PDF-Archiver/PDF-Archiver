//
//  MoreTabViewModel+StorageType.swift
//  
//
//  Created by Julian Kahnert on 18.11.20.
//

import SwiftUI

extension MoreTabViewModel {
    enum StorageType: String, CaseIterable, Identifiable, Hashable {
        case iCloudDrive
        case appContainer
        case local

        static func getCurrent() -> StorageType {
            let type = PathManager.shared.archivePathType
            switch type {
                case .iCloudDrive:
                    return .iCloudDrive
                case .appContainer:
                    return .appContainer
                case .local:
                    return .local
            }
        }

        var id: String {
            rawValue
        }

        var title: LocalizedStringKey {
            switch self {
                case .iCloudDrive:
                    return "☁️ iCloud Drive"
                case .appContainer:
                    return "📱 Local"
                case .local:
					#if os(macOS)
                    return "💾 Drive"
					#else
					return "📁 Folder"
					#endif
            }
        }

        @ViewBuilder
        var descriptionView: some View {
            switch self {
                case .iCloudDrive:
                    Text("Synchronized - Your documents are stored in iCloud Drive. They are available to you on all devices with the same iCloud account, e.g. iPhone, iPad and Mac.")
                case .appContainer:
                    VStack(alignment: .leading) {
                        Text("Not synchronized - your documents are only stored locally in this app. They can be transferred via the Finder on a Mac, for example.")
                        // swiftlint:disable:next force_unwrapping
                        Link("https://support.apple.com/en-us/HT210598", destination: URL(string: NSLocalizedString("https://support.apple.com/en-us/HT210598", comment: ""))!)
                    }
                case .local:
                    Text("Not synchronized - Your documents are stored in a folder you choose on your computer. PDF Archiver does not initiate synchronization.")
            }
        }
    }
}
