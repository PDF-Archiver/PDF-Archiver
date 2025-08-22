//
//  Settings.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 30.06.25.
//

import ArchiverModels
import ComposableArchitecture
import Shared
import SwiftUI
import StoreKit

extension PDFQuality {
    var name: LocalizedStringKey {
        switch self {
        case .lossless:
            return "100% - Lossless 🤯"
        case .good:
            return "75% - Good 👌 (Default)"
        case .normal:
            return "50% - Normal 👍"
        case .small:
            return "25% - Small 💾"
        }
    }
}

extension StorageType {
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

@Reducer
struct Settings {
    @Reducer
    enum Destination {
        case archiveStorage
        case expertSettings(ExpertSettings)
        case aboutMe
        case termsAndPrivacy
        case imprint
    }

    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?
        
        @Shared(.pdfQuality)
        var pdfQuality: PDFQuality = .normal
        
        @Shared(.archivePathType)
        var selectedArchiveType: StorageType = .iCloudDrive
        
        let appStoreUrl = URL(string: "https://apps.apple.com/app/pdf-archiver/id1433801905")!
        let pdfArchiverWebsiteUrl = URL(string: "https://pdf-archiver.io")!
        let termsOfUseUrl = URL(string: "https://pdf-archiver.io/terms")!
    }
    
    @Dependency(\.openURL) var openURL

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case onAboutMeTapped
        case onContactSupportTapped
        case onImprintTapped
        case onOpenPdfArchiverWebsiteTapped
        case onShowArchiveTypeSelectionTapped
        case onTermsAndPrivacyTapped
        case onTermsOfUseTapped
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .onAboutMeTapped:
#warning("TODO: Add this")
//                NavigationLink(destination: AboutMeView()) {
//                    Text("About  👤")
//                }
                return .none
            case .onContactSupportTapped:
#warning("TODO: Add this")
                return .none
            case .onImprintTapped:
#warning("TODO: Add this")
//                SettingsViewModel.markdownView(for: "Imprint", withKey: "Imprint")
                return .none
            case .onOpenPdfArchiverWebsiteTapped:
                return .run { [pdfArchiverWebsiteUrl = state.pdfArchiverWebsiteUrl] _ in
                    await openURL(pdfArchiverWebsiteUrl)
                }
                
            case .onShowArchiveTypeSelectionTapped:
                #warning("TODO: Add this")
                return .none
                
            case .onTermsAndPrivacyTapped:
                #warning("TODO: Add this")
//                SettingsViewModel.markdownView(for: "Terms & Privacy", withKey: "Privacy")
                return .none

            case .onTermsOfUseTapped:
                return .run { [termsOfUseUrl = state.termsOfUseUrl] _ in
                    await openURL(termsOfUseUrl)
                }
            case .destination(_):
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension Settings.Destination.State: Sendable, Equatable {}

struct SettingsView: View {
    @Bindable var store: StoreOf<Settings>
    private static let appId = 1433801905

    @Environment(\.requestReview) private var requestReview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                preferences
//                PremiumSectionView()
                moreInformation
            }
            .foregroundColor(.primary)
            .navigationTitle("Preferences & More")
            #if os(iOS)
            .navigationViewStyle(StackNavigationViewStyle())
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            #endif
        }
        .navigationDestination(
          item: $store.scope(
            state: \.destination?.expertSettings,
            action: \.destination.expertSettings
          )
        ) { store in
          ExpertSettingsView(store: store)
        }
    }

    @ViewBuilder
    private var preferences: some View {
        Section {
            Picker(selection: $store.pdfQuality, label: Text("PDF Quality")) {
                ForEach(PDFQuality.allCases, id: \.self) { quality in
                    Text(quality.name)
                }
            }

            Button {
                store.send(.onShowArchiveTypeSelectionTapped)
//                viewModel.showArchiveTypeSelection = true
            } label: {
                HStack {
                    Text("Storage")
                    Spacer()
                    Text(store.selectedArchiveType.title)
                }
            }
//            .navigationDestination(isPresented: $viewModel.showArchiveTypeSelection) {
//                StorageSelectionView(selection: $viewModel.selectedArchiveType, onCompletion: viewModel.handleDocumentPicker)
//            }
//
//            Button("Open Archive Folder", action: viewModel.openArchiveFolder)
//                // if statement in view not possible, because the StorageSelectionView was not returning to the overview
//                // after the selection has changed.
//                .disabled(!PathManager.shared.archivePathType.isFileBrowserCompatible)
//                .opacity(PathManager.shared.archivePathType.isFileBrowserCompatible ? 1 : 0.3)
//            NavigationLink(destination: ExpertSettingsView(notSaveDocumentTagsAsPDFMetadata: $viewModel.notSaveDocumentTagsAsPDFMetadata,
//                                                           documentTagsNotRequired: $viewModel.documentTagsNotRequired,
//                                                           documentSpecificationNotRequired: $viewModel.documentSpecificationNotRequired,
//                                                           showPermissions: viewModel.showPermissions,
//                                                           resetApp: viewModel.resetApp)) {
//                Text("Advanced")
//            }
        } header: {
            Text("🛠 Preferences")
        }
    }

    private var moreInformation: some View {
        Section(header: Text("⁉️ More Information")) {
            Button("About  👤") {
                store.send(.onAboutMeTapped)
            }
            Button("PDF Archiver Website  🖥") {
                store.send(.onOpenPdfArchiverWebsiteTapped)
            }
            Button("Terms of Use") {
                store.send(.onTermsOfUseTapped)
            }
            Button("Terms & Privacy") {
                store.send(.onTermsAndPrivacyTapped)
            }
            Button("Imprint") {
                store.send(.onImprintTapped)
            }
            Button("Contact Support  🚑") {
                store.send(.onContactSupportTapped)
            }
            Button("Rate App ⭐️") {
                requestReview()
            }
            ShareLink(item: store.appStoreUrl) {
                Text("Share PDF Archiver 📱❤️🫵")
            }
        }
    }
}

#Preview("Settings", traits: .fixedLayout(width: 800, height: 600)) {
    SettingsView(
        store: Store(initialState: Settings.State()) {
            Settings()
                ._printChanges()
        }
    )
}
