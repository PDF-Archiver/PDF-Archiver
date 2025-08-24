//
//  Settings.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 30.06.25.
//

import ArchiverModels
import ComposableArchitecture
import Shared
import StoreKit
import SwiftUI

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
        case onAdvancedSettingsTapped
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
                state.destination = .aboutMe
                return .none

            case .onAdvancedSettingsTapped:
                state.destination = .expertSettings(.init())
                return .none

            case .onContactSupportTapped:
                let url = URL(string: "mailto:\(Constants.mailRecipient)?subject=\(Constants.mailSubject)")!
                return .run { [url] _ in
                    await openURL(url)
                }

            case .onImprintTapped:
                state.destination = .imprint
                return .none

            case .onOpenPdfArchiverWebsiteTapped:
                return .run { [pdfArchiverWebsiteUrl = state.pdfArchiverWebsiteUrl] _ in
                    await openURL(pdfArchiverWebsiteUrl)
                }

            case .onShowArchiveTypeSelectionTapped:
                state.destination = .archiveStorage
                return .none

            case .onTermsAndPrivacyTapped:
                state.destination = .termsAndPrivacy
                return .none

            case .onTermsOfUseTapped:
                return .run { [termsOfUseUrl = state.termsOfUseUrl] _ in
                    await openURL(termsOfUseUrl)
                }

            case .destination:
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
                #warning("TODO: add the premium section here")
                //                PremiumSectionView()
                moreInformation
            }
            // since we have buttons, we have to "fake" the foreground color - it would be the accent color otherwise
            .foregroundColor(.primary)
            .navigationTitle("Preferences & More")
#if os(iOS)
            .navigationViewStyle(StackNavigationViewStyle())
            .navigationBarTitleDisplayMode(.inline)
#endif
            .navigationDestination(item: $store.destination) { destination in
                switch destination {
                case .archiveStorage:
                    #warning("TODO: fix this")
                    Text("archiveStorage", bundle: #bundle)
                    //                StorageSelectionView(selection: $viewModel.selectedArchiveType, onCompletion: viewModel.handleDocumentPicker)
                case .expertSettings:
                    #warning("TODO: fix this")
                    Text("expertSettings(ExpertSettings)", bundle: #bundle)
                    //                ExpertSettingsView(notSaveDocumentTagsAsPDFMetadata: $viewModel.notSaveDocumentTagsAsPDFMetadata,
                                    //                                                           documentTagsNotRequired: $viewModel.documentTagsNotRequired,
                                    //                                                           documentSpecificationNotRequired: $viewModel.documentSpecificationNotRequired,
                                    //                                                           showPermissions: viewModel.showPermissions,
                                    //                                                           resetApp: viewModel.resetApp)

                case .aboutMe:
                    AboutMeView()
                case .termsAndPrivacy:
                    let content = String(localized: "TERMS_AND_PRIVACY", bundle: #bundle)
                    MarkdownView(markdown: content)
                        .navigationTitle(String(localized: "Terms & Privacy", bundle: #bundle))
                case .imprint:
                    let content = String(localized: "IMPRINT", bundle: #bundle)
                    MarkdownView(markdown: content)
                        .navigationTitle(Text("Imprint", bundle: #bundle))
                }
            }
        }
    }

    @ViewBuilder
    private var preferences: some View {
        Section {
            Picker(selection: $store.pdfQuality, label: Text("PDF Quality", bundle: #bundle)) {
                ForEach(PDFQuality.allCases, id: \.self) { quality in
                    Text(quality.name, bundle: #bundle)
                }
            }

            Button {
                store.send(.onShowArchiveTypeSelectionTapped)
            } label: {
                HStack {
                    Text("Storage", bundle: #bundle)
                    Spacer()
                    Text(store.selectedArchiveType.title, bundle: #bundle)
                }
            }

            Button {
                store.send(.onAdvancedSettingsTapped)
            } label: {
                Text("Advanced", bundle: #bundle)
            }
        } header: {
            Text("🛠 Preferences")
        }
    }

    private var moreInformation: some View {
        Section(header: Text("⁉️ More Information", bundle: #bundle)) {
            Button {
                store.send(.onAboutMeTapped)
            } label: {
                Text("About  👤", bundle: #bundle)
            }
            Button {
                store.send(.onOpenPdfArchiverWebsiteTapped)
            } label: {
                Text("PDF Archiver Website  🖥", bundle: #bundle)
            }
            Button {
                store.send(.onTermsOfUseTapped)
            } label: {
                Text("Terms of Use", bundle: #bundle)
            }
            Button {
                store.send(.onTermsAndPrivacyTapped)
            } label: {
                Text("Terms & Privacy", bundle: #bundle)
            }
            Button {
                store.send(.onImprintTapped)
            } label: {
                Text("Imprint", bundle: #bundle)
            }
            Button {
                store.send(.onContactSupportTapped)
            } label: {
                Text("Contact Support  🚑", bundle: #bundle)
            }
            Button {
                requestReview()
            } label: {
                Text("Rate App ⭐️", bundle: #bundle)
            }
            ShareLink(item: store.appStoreUrl) {
                Text("Share PDF Archiver 📱❤️🫵", bundle: #bundle)
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
