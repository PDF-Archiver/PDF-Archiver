//
//  StorageSelection.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 30.06.25.
//

import ArchiverModels
import ComposableArchitecture
import OSLog
import Shared
import SwiftUI
import UniformTypeIdentifiers

@Reducer
struct StorageSelection {

    @ObservableState
    struct State: Equatable {
        @Shared(.archivePathType) var selectedArchiveType: StorageType?
        var showDocumentPicker = false
        var isProcessing = false
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onStorageTypeTapped(StorageSelectionType)
        case moveToStorageTypeStart(StorageType)
        case moveToStorageTypeEndWithNew(StorageType?)
    }

    @Dependency(\.archiveStore) var archiveStore
    @Dependency(\.userDefaultsManager) var userDefaultsManager
    @Dependency(\.notificationCenter) var notificationCenter

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
//            case .binding(\.selectedArchiveType):
//                userDefaultsManager.setArchivePathType(state.selectedArchiveType)
//                return .none

            case .binding:
                return .none

            case .onStorageTypeTapped(let type):
                switch type {
                case .iCloudDrive:
                    return .send(.moveToStorageTypeStart(.iCloudDrive))

                #if !os(macOS)
                case .appContainer:
                    return .send(.moveToStorageTypeStart(.appContainer))
                #endif

                case .local:
                    state.showDocumentPicker = true
                }
                return .none

            case .moveToStorageTypeStart(let type):
                state.isProcessing = true

                return .run { send in
                    do {
                        try await archiveStore.setArchiveStorageType(type)
                        await send(.moveToStorageTypeEndWithNew(type))
                    } catch {
                        await notificationCenter.postAlert(error)
                        await send(.moveToStorageTypeEndWithNew(nil))
                    }
                }

            case .moveToStorageTypeEndWithNew(let type):
                state.isProcessing = false

                if let type {
                    state.$selectedArchiveType.withLock { $0 = type }
                }
                return .none
            }
        }
    }
}

struct StorageSelectionView: View {
    @Bindable var store: StoreOf<StorageSelection>

    var body: some View {
        Form {
            ForEach(StorageSelectionType.allCases, id: \.rawValue) { storageType in
                Section(footer: storageType.descriptionView) {
                    Button {
                        store.send(.onStorageTypeTapped(storageType))

                    } label: {
                        HStack {
                            Label {
                                Text(storageType.title, bundle: .module)
                            } icon: {
                                Image(systemName: storageType.icon)
                            }
                            // since we have buttons, we have to "fake" the foreground color - it would be the accent color otherwise
                            .foregroundColor(.primary)
                            Spacer()
                            if storageType.equals(store.selectedArchiveType.getPath()) {
                                Image(systemName: "checkmark.circle.fill")
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

                Text("PDF Archiver is not a backup solution. Please make backups of the archived PDFs regularly.", bundle: .module)
                    .foregroundStyle(Color.secondaryLabelAsset)
                    .font(.footnote)
            }
            .fileImporter(isPresented: $store.showDocumentPicker, allowedContentTypes: [UTType.folder], onCompletion: { result in
                switch result {
                case .success(let url):
                    // Securely access the URL to save a bookmark
                    guard url.startAccessingSecurityScopedResource() else {
                        // Handle the failure here.
                        return
                    }
                    store.send(.moveToStorageTypeStart(.local(url)))

                case .failure(let error):
                    Logger.settings.faultAndAssert("Failed to import a local folder: \(error)")
                    NotificationCenter.default.postAlert(error)
                }
                store.showDocumentPicker = false
            })
        }
        .padding()
        .disabled(store.isProcessing)
        .overlay {
            if store.isProcessing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Migrating documents...", bundle: .module)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .padding(32)
                .background(.regularMaterial)
                .cornerRadius(16)
            }
        }
    }
}

enum StorageSelectionType: String, CaseIterable {
    case iCloudDrive
    #if !os(macOS)
    case appContainer
    #endif
    case local

    // swiftlint:disable:next force_unwrapping
    private static let appleDocumentationURL = URL(string: "https://support.apple.com/en-us/HT210598")!

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
                return "iCloud Drive"
            #if !os(macOS)
            case .appContainer:
                return "Local"
            #endif
            case .local:
                #if os(macOS)
                return "Drive"
                #else
                return "Folder"
                #endif
        }
    }

    var icon: String {
        switch self {
            case .iCloudDrive:
                return "icloud"
            #if !os(macOS)
            case .appContainer:
                return "iphone"
            #endif
            case .local:
                #if os(macOS)
                return "externaldrive"
                #else
                return "folder"
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
                    Link("https://support.apple.com/en-us/HT210598", destination: Self.appleDocumentationURL)
                }
            #endif
            case .local:
                Text("Not synchronized - Your documents are stored in a folder you choose on your computer. PDF Archiver does not initiate synchronization.", bundle: .module)
        }
    }
}

#Preview("StorageSelection", traits: .fixedLayout(width: 800, height: 600)) {
    StorageSelectionView(
        store: Store(initialState: StorageSelection.State()) {
            StorageSelection()
                ._printChanges()
        }
    )
}
