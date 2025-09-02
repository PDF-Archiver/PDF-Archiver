//
//  StorageSelectionView.swift
//  
//
//  Created by Julian Kahnert on 18.11.20.
//

import ArchiverModels
import OSLog
import Shared
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
                            Text(storageType.title, bundle: .module)
                                // since we have buttons, we have to "fake" the foreground color - it would be the accent color otherwise
                                .foregroundColor(.primary)
                            Spacer()
                            if storageType.equals(selection) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(Color.green)
                            }
                        }
                    }
                }
                #if os(macOS)
                Spacer(minLength: 8)
                #endif
            }
            HStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .resizable()
                    .scaledToFit()
                    .containerRelativeFrame(.horizontal) { size, _ in
                        size * 1 / 10
                    }
                    .foregroundStyle(Color.tertiaryLabelAsset)

                Text("PDF Archiver is not a backup solution. Please make backups of the archieved PDFs regularly.", bundle: .module)
                    .foregroundStyle(Color.secondaryLabelAsset)
                    .font(.footnote)
            }
            .padding(.vertical)
            .navigationTitle(Text("Storage", bundle: .module))
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
                    Text("Synchronized - Your documents are stored in iCloud Drive. They are available to you on all devices with the same iCloud account, e.g. iPhone, iPad and Mac.", bundle: .module)
                #if !os(macOS)
                case .appContainer:
                    VStack(alignment: .leading) {
                        Text("Not synchronized - your documents are only stored locally in this app. They can be transferred via the Finder on a Mac, for example.", bundle: .module)
                        // swiftlint:disable:next force_unwrapping
                        Link("https://support.apple.com/en-us/HT210598", destination: URL(string: NSLocalizedString("https://support.apple.com/en-us/HT210598", comment: ""))!)
                    }
                #endif
                case .local:
                    Text("Not synchronized - Your documents are stored in a folder you choose on your computer. PDF Archiver does not initiate synchronization.", bundle: .module)
            }
        }
    }
}

#Preview {
    StorageSelectionView(selection: .constant(.iCloudDrive))
}
