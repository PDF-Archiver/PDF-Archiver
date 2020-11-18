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
                    return "💾 Drive"
            }
        }

        @ViewBuilder
        var descriptionView: some View {
            switch self {
                case .iCloudDrive:
                    Text("Synchronized - Your documents are stored in iCloud Drive. They are available to you on all devices with the same iCloud account, e.g. iPhone, iPad and Mac.")
                case .appContainer:
                    VStack(alignment: .leading) {
                        Text("Not synchronized - your documents are only stored locally on this device. They can be transferred via the Finder on a Mac, for example.")
                        Button("https://support.apple.com/en-us/HT210598") {
                            // TODO: test this
                            let url = URL(string: NSLocalizedString("https://support.apple.com/en-us/HT210598", comment: ""))!
                            open(url)
                        }
                    }
                case .local:
                    // TODO: add text
                    Text("💾 Drive")
            }
        }
    }
}
