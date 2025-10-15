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
#if os(iOS)
import MessageUI
#endif

extension PDFQuality {
    var name: LocalizedStringKey {
        switch self {
        case .lossless:
            return "100% - Lossless"
        case .good:
            return "75% - Good (Default)"
        case .normal:
            return "50% - Normal"
        case .small:
            return "25% - Small"
        }
    }
}

extension StorageType {
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
        case archiveStorage(StorageSelection)
        case expertSettings(ExpertSettings)
        case imprint
        case legal
        case privacy
        case termsOfUse
    }

    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?

        @Shared(.pdfQuality) var pdfQuality: PDFQuality
        @SharedReader(.archivePathType) var selectedArchiveType: StorageType?

        var premiumSection = PremiumSection.State()
        var isShowingMailSheet = false

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
        case onLegalTapped
        case onOpenPdfArchiverWebsiteTapped
        case onShowArchiveTypeSelectionTapped
        case onPrivacyTapped
        case onTermsOfUseTapped
        case premiumSection(PremiumSection.Action)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(state: \.premiumSection, action: \.premiumSection) {
            PremiumSection()
        }
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
                #if os(iOS)
                state.isShowingMailSheet = true
                return .none
                #else
                let url = URL(string: "mailto:\(Constants.mailRecipient)?subject=\(Constants.mailSubject)")!
                return .run { [url] _ in
                    await openURL(url)
                }
                #endif

            case .onImprintTapped:
                state.destination = .imprint
                return .none

            case .onLegalTapped:
                state.destination = .legal
                return .none

            case .onOpenPdfArchiverWebsiteTapped:
                return .run { [pdfArchiverWebsiteUrl = state.pdfArchiverWebsiteUrl] _ in
                    await openURL(pdfArchiverWebsiteUrl)
                }

            case .onShowArchiveTypeSelectionTapped:
                state.destination = .archiveStorage(StorageSelection.State())
                return .none

            case .onPrivacyTapped:
                state.destination = .privacy
                return .none

            case .onTermsOfUseTapped:
                state.destination = .termsOfUse
                return .none

            case .premiumSection(.delegate):
                // Forward delegate actions to parent
                return .none

            case .premiumSection:
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
                aboutSection
            }
            // since we have buttons, we have to "fake" the foreground color - it would be the accent color otherwise
            .foregroundColor(.primary)
            .navigationTitle(Text("Preferences & More", bundle: .module))
#if os(iOS)
            .navigationViewStyle(StackNavigationViewStyle())
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $store.isShowingMailSheet) {
                if MFMailComposeViewController.canSendMail() {
                    MailComposeView(
                        isShowing: $store.isShowingMailSheet,
                        recipient: Constants.mailRecipient,
                        subject: Constants.mailSubject
                    )
                } else {
                    Text("Mail is not configured on this device", bundle: .module)
                        .padding()
                }
            }
#endif
            .navigationDestination(item: $store.destination) { destination in
                switch destination {
                case .archiveStorage:
                    if let storageSelectionStore = store.scope(state: \.destination?.archiveStorage, action: \.destination.archiveStorage) {
                        StorageSelectionView(store: storageSelectionStore)
                            .navigationTitle(Text("Storage", bundle: .module))
                    } else {
                        preconditionFailure("Failed to load export nothing found")
                    }
                case .expertSettings:
                    if let expertSettingsStore = store.scope(state: \.destination?.expertSettings, action: \.destination.expertSettings) {
                        ExpertSettingsView(store: expertSettingsStore)
                            .navigationTitle(Text("Advanced", bundle: .module))
                    } else {
                        preconditionFailure("Failed to load export nothing found")
                    }
                case .aboutMe:
                    AboutMeView()
                case .legal:
                    LegalView(store: store)
                        .navigationTitle(Text("Legal", bundle: .module))
                case .termsOfUse:
                    let content = String(localized: "TERMS_OF_USE", bundle: .module)
                    MarkdownView(markdown: content)
                        .navigationTitle(String(localized: "Terms of Use", bundle: .module))
                case .privacy:
                    let content = String(localized: "PRIVACY", bundle: .module)
                    MarkdownView(markdown: content)
                        .navigationTitle(String(localized: "Privacy", bundle: .module))
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
            Picker(selection: $store.pdfQuality, label: Label(String(localized: "PDF Quality", bundle: .module), systemImage: "text.document")) {
                ForEach(PDFQuality.allCases, id: \.self) { quality in
                    Text(quality.name, bundle: .module)
                }
            }

            Button {
                store.send(.onShowArchiveTypeSelectionTapped)
            } label: {
                HStack {
                    Label(String(localized: "Storage", bundle: .module), systemImage: "externaldrive")
                    Spacer()
                    Text(store.selectedArchiveType.getPath().title, bundle: .module)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                store.send(.onAdvancedSettingsTapped)
            } label: {
                Label(String(localized: "Advanced", bundle: .module), systemImage: "gearshape.2")
            }
        } header: {
            Text("Preferences", bundle: .module)
                .foregroundStyle(Color.secondary)
        }
    }

    private var aboutSection: some View {
        Section {
            Button {
                store.send(.onContactSupportTapped)
            } label: {
                Label(String(localized: "Contact & Help", bundle: .module), systemImage: "envelope")
            }

            Button {
                requestReview()
            } label: {
                Label(String(localized: "Rate App", bundle: .module), systemImage: "app.gift.fill")
            }

            ShareLink(item: store.appStoreUrl) {
                Label(String(localized: "Share App", bundle: .module), systemImage: "square.and.arrow.up")
            }

            Button {
                store.send(.onLegalTapped)
            } label: {
                Label(String(localized: "Legal", bundle: .module), systemImage: "checkmark.seal.text.page")
            }
        } header: {
            Text("About", bundle: .module)
                .foregroundStyle(Color.secondary)
        }
    }
}

#if os(macOS)
struct SettingsMacView: View {
    @Bindable var store: StoreOf<Settings>
    private static let appId = 1433801905

    @Environment(\.requestReview) private var requestReview

    var body: some View {
        TabView {
            Tab(String(localized: "General", bundle: .module), systemImage: "gear") {
                generalPreferences
            }

            Tab(String(localized: "Premium", bundle: .module), systemImage: "star.hexagon") {
                PremiumSectionView(store: store.scope(state: \.premiumSection, action: \.premiumSection))
            }

            Tab(String(localized: "About", bundle: .module), systemImage: "info.circle") {
                aboutPreferences
            }
        }
        .tabViewStyle(.tabBarOnly)
        .frame(width: 500, height: 400)
        .navigationDestination(item: $store.destination) { destination in
            switch destination {
            case .archiveStorage:
                if let storageSelectionStore = store.scope(state: \.destination?.archiveStorage, action: \.destination.archiveStorage) {
                    StorageSelectionView(store: storageSelectionStore)
                        .navigationTitle(Text("Storage", bundle: .module))
                } else {
                    preconditionFailure("Failed to load storage selection")
                }
            case .expertSettings:
                if let expertSettingsStore = store.scope(state: \.destination?.expertSettings, action: \.destination.expertSettings) {
                    ExpertSettingsView(store: expertSettingsStore)
                        .navigationTitle(Text("Advanced", bundle: .module))
                } else {
                    preconditionFailure("Failed to load expert settings")
                }
            case .aboutMe:
                AboutMeView()
            case .legal:
                LegalView(store: store)
                    .navigationTitle(Text("Legal", bundle: .module))
            case .termsOfUse:
                let content = String(localized: "TERMS_OF_USE", bundle: .module)
                MarkdownView(markdown: content)
                    .navigationTitle(String(localized: "Terms of Use", bundle: .module))
            case .privacy:
                let content = String(localized: "PRIVACY", bundle: .module)
                MarkdownView(markdown: content)
                    .navigationTitle(String(localized: "Privacy", bundle: .module))
            case .imprint:
                let content = String(localized: "IMPRINT", bundle: .module)
                MarkdownView(markdown: content)
                    .navigationTitle(Text("Imprint", bundle: .module))
            }
        }
    }

    @ViewBuilder
    private var generalPreferences: some View {
        Form {
            Section {
                LabeledContent {
                    Picker("", selection: $store.pdfQuality) {
                        ForEach(PDFQuality.allCases, id: \.self) { quality in
                            Text(quality.name, bundle: .module)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                } label: {
                    Text("PDF Quality:", bundle: .module)
                }

                LabeledContent {
                    HStack {
                        Text(store.selectedArchiveType.getPath().title, bundle: .module)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(String(localized: "Change…", bundle: .module)) {
                            store.send(.onShowArchiveTypeSelectionTapped)
                        }
                    }
                } label: {
                    Text("Storage:", bundle: .module)
                }
            } header: {
                Label(String(localized: "PDF Processing", bundle: .module), systemImage: "doc.fill")
            }

            Section {
                HStack(alignment: .top, spacing: 12) {
                    Text("Advanced settings allow you to configure additional options for PDF processing and organization.", bundle: .module)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button(String(localized: "Configure…", bundle: .module)) {
                        store.send(.onAdvancedSettingsTapped)
                    }
                }
            } header: {
                Label(String(localized: "Advanced", bundle: .module), systemImage: "gearshape.2.fill")
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var aboutPreferences: some View {
        Form {
            Section {
                HStack(spacing: 20) {
                    Button(String(localized: "Contact & Help", bundle: .module)) {
                        store.send(.onContactSupportTapped)
                    }
                    .buttonStyle(.link)

                    Spacer()

                    Button(String(localized: "Rate App", bundle: .module)) {
                        requestReview()
                    }
                    .buttonStyle(.link)
                }

                Divider()

                HStack(spacing: 20) {
                    ShareLink(item: store.appStoreUrl) {
                        Text("Share App", bundle: .module)
                    }
                    .buttonStyle(.link)

                    Spacer()
                }
            } header: {
                Label(String(localized: "Support & Feedback", bundle: .module), systemImage: "envelope")
            }

            Section {
                Button(String(localized: "About Developer", bundle: .module)) {
                    store.send(.onAboutMeTapped)
                }
                .buttonStyle(.link)
                .frame(maxWidth: .infinity, alignment: .leading)
            } header: {
                Label(String(localized: "Developer", bundle: .module), systemImage: "person.fill")
            }

            Section {
                Button {
                    store.send(.onLegalTapped)
                } label: {
                    Text("Legal", bundle: .module)
                }
            } header: {
                Label(String(localized: "Legal", bundle: .module), systemImage: "checkmark.seal.text.page")
            }
        }
        .formStyle(.grouped)
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

#Preview("Settings Mac", traits: .fixedLayout(width: 500, height: 400)) {
    SettingsMacView(
        store: Store(initialState: Settings.State()) {
            Settings()
                ._printChanges()
        }
    )
}
#endif
