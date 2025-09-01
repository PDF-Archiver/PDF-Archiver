//
//  StorageSelectionView.swift
//  
//
//  Created by Julian Kahnert on 18.11.20.
//

import ArchiverModels
import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct StorageSelectionView: View {
    @Binding var selection: StorageType

    @State private var showDocumentPicker = false

    var body: some View {
        Form {
            ForEach(StorageSelection.allCases, id: \.rawValue) { storageType in
                Section(footer: storageType.descriptionView) {
                    Button {
                        switch storageType {
                        case .iCloudDrive:
                            selection = .iCloudDrive

                        #if !os(macOS)
                        case .appContainer:
                            selection = .appContainer
                        #endif

                        case .local:
                            showDocumentPicker = true
                        }
                    } label: {
                        HStack {
                            Text(storageType.title)
                                .fixedSize()
                            Spacer()
                            if storageType.equals(selection) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                #if os(macOS)
                Spacer(minLength: 8)
                #endif
            }
            Text("PDF Archiver is not a backup solution. Please make backups of the archieved PDFs regularly.")
                .foregroundStyle(.secondary)
                .font(.footnote)
                .padding(.vertical)
            .fileImporter(isPresented: $showDocumentPicker, allowedContentTypes: [UTType.folder], onCompletion: { result in
                switch result {
                case .success(let url):
                    // Securely access the URL to save a bookmark
                    guard url.startAccessingSecurityScopedResource() else {
                        // Handle the failure here.
                        return
                    }
                    selection = .local(url)

                case .failure(let error):
                    Logger.settings.faultAndAssert("Failed to import a local folder: \(error)")
                    NotificationCenter.default.postAlert(error)
                }
                showDocumentPicker = false
            })
        }
    }
}

extension StorageSelectionView {
    private enum StorageSelection: String, CaseIterable {
        case iCloudDrive
        #if !os(macOS)
        case appContainer
        #endif
        case local

        func equals(_ type: StorageType) -> Bool {
            switch type {
            case .iCloudDrive:
                return self == .iCloudDrive

            #if !os(macOS)
            case .appContainer:
                return self == .appContainer
            #endif

            case .local:
                return self == .local
            }
        }

        var title: LocalizedStringKey {
            switch self {
                case .iCloudDrive:
                    return "☁️ iCloud Drive"
                #if !os(macOS)
                case .appContainer:
                    return "📱 Local"
                #endif
                case .local:
                    #if os(macOS)
                    return "💾 Drive"
                    #else
                    return "🗂️ Folder"
                    #endif
            }
        }

        @ViewBuilder
        var descriptionView: some View {
            switch self {
                case .iCloudDrive:
                    Text("Synchronized - Your documents are stored in iCloud Drive. They are available to you on all devices with the same iCloud account, e.g. iPhone, iPad and Mac.")
                #if !os(macOS)
                case .appContainer:
                    VStack(alignment: .leading) {
                        Text("Not synchronized - your documents are only stored locally in this app. They can be transferred via the Finder on a Mac, for example.")
                        // swiftlint:disable:next force_unwrapping
                        Link("https://support.apple.com/en-us/HT210598", destination: URL(string: NSLocalizedString("https://support.apple.com/en-us/HT210598", comment: ""))!)
                    }
                #endif
                case .local:
                    Text("Not synchronized - Your documents are stored in a folder you choose on your computer. PDF Archiver does not initiate synchronization.")
            }
        }
    }
}

#Preview {
    StorageSelectionView(selection: .constant(.iCloudDrive))
}
