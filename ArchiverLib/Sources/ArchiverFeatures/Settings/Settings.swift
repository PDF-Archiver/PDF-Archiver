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

@Reducer
struct Settings {
    @Reducer
    enum Destination {
        case aboutMe
        case archiveStorage
        case expertSettings(ExpertSettings)
        case imprint
        case termsAndPrivacy
    }

    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?

        @Shared(.pdfQuality)
        var pdfQuality: PDFQuality = .normal

        @Shared(.archivePathType)
        var selectedArchiveType: StorageType = .iCloudDrive

        let premiumSection = PremiumSection.State()

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
        case premiumSection(PremiumSection.Action)
        case receiveStoragePickerResult(Result<URL, any Error>)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .destination:
                return .none

            case .onAboutMeTapped:
                state.destination = .aboutMe
                return .none

            case .onAdvancedSettingsTapped:
                state.destination = .expertSettings(ExpertSettings.State())
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

            case .premiumSection:
                return .none

            case .receiveStoragePickerResult(let result):
                #warning("TODO: implement storage picker result handling")
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
                PremiumSectionView(store: store.scope(state: \.premiumSection, action: \.premiumSection))
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
                    StorageSelectionView(selection: $store.selectedArchiveType,
                                         onCompletion: { result in
                        store.send(.receiveStoragePickerResult(result))
                    })
                case .expertSettings:
                    if let expertSettingsStore = store.scope(state: \.destination?.expertSettings, action: \.destination.expertSettings) {
                        ExpertSettingsView(store: expertSettingsStore)
                    } else {
                        preconditionFailure("Failed to load export nothing found")
                    }
                case .aboutMe:
                    AboutMeView()
                case .termsAndPrivacy:
                    let content = String(localized: "TERMS_AND_PRIVACY", bundle: .module)
                    MarkdownView(markdown: content)
                        .navigationTitle(String(localized: "Terms & Privacy", bundle: .module))
                case .imprint:
                    let content = String(localized: "IMPRINT", bundle: .module)
                    MarkdownView(markdown: content)
                        .navigationTitle(Text("Imprint", bundle: .module))
                }
            }
        }
    }

    @ViewBuilder
    private var preferences: some View {
        Section {
            Picker(selection: $store.pdfQuality, label: Text("PDF Quality", bundle: .module)) {
                ForEach(PDFQuality.allCases, id: \.self) { quality in
                    Text(quality.name, bundle: .module)
                }
            }

            Button {
                store.send(.onShowArchiveTypeSelectionTapped)
            } label: {
                HStack {
                    Text("Storage", bundle: .module)
                    Spacer()
                    Text(store.selectedArchiveType.title, bundle: .module)
                }
            }

            Button {
                store.send(.onAdvancedSettingsTapped)
            } label: {
                Text("Advanced", bundle: .module)
            }
        } header: {
            Text("🛠 Preferences")
        }
    }

    private var moreInformation: some View {
        Section(header: Text("⁉️ More Information", bundle: .module)) {
            Button {
                store.send(.onAboutMeTapped)
            } label: {
                Text("About  👤", bundle: .module)
            }
            Button {
                store.send(.onOpenPdfArchiverWebsiteTapped)
            } label: {
                Text("PDF Archiver Website  🖥", bundle: .module)
            }
            Button {
                store.send(.onTermsOfUseTapped)
            } label: {
                Text("Terms of Use", bundle: .module)
            }
            Button {
                store.send(.onTermsAndPrivacyTapped)
            } label: {
                Text("Terms & Privacy", bundle: .module)
            }
            Button {
                store.send(.onImprintTapped)
            } label: {
                Text("Imprint", bundle: .module)
            }
            Button {
                store.send(.onContactSupportTapped)
            } label: {
                Text("Contact Support  🚑", bundle: .module)
            }
            Button {
                requestReview()
            } label: {
                Text("Rate App ⭐️", bundle: .module)
            }
            ShareLink(item: store.appStoreUrl) {
                Text("Share PDF Archiver 📱❤️🫵", bundle: .module)
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
