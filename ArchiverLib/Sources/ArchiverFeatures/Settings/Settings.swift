//
//  Settings.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 30.06.25.
//

import ArchiverDatabase
import ArchiverModels
import ArchiverStore
import ComposableArchitecture
import Shared
import StoreKit
import SwiftUI

extension PDFQuality {
    var name: LocalizedStringKey {
        switch self {
        case .lossless:
            return "100% - Lossless"

        case .good:
            return "75% - Good"

        case .normal:
            return "50% - Normal"

        case .small:
            return "25% - Small"
        }
    }

    /// Read from the stored key itself, so the picker's "(Default)" cannot name another case than
    /// the one a fresh install gets.
    static var `default`: PDFQuality {
        AppStorageKey<PDFQuality>.Default.pdfQuality.initialValue
    }

    var pickerLabel: Text {
        guard self == Self.default else { return Text(name, bundle: #bundle) }
        return Text(name, bundle: #bundle) + Text(verbatim: " ") + Text("(Default)", bundle: #bundle)
    }
}

@Reducer
struct Settings {
    @Reducer
    enum Destination {
        case aboutMe
        case appleIntelligenceSettings(AppleIntelligenceSettings)
        case archiveStorage(StorageSelection)
        case expertSettings(ExpertSettings)
        case imprint
        case legal
        case premium
        case privacy
        case searchIndex(SearchIndexSettings)
        case termsOfUse
    }

    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?
        var navigationStackID = 0

        @Shared(.pdfQuality) var pdfQuality: PDFQuality
        @SharedReader(.archivePathType) var selectedArchiveType: StorageType?
        #if os(macOS)
        @Shared(.observedFolder) var observedFolderURL: URL?
        @Shared(.settingsPane) var selectedPaneID: String

        var selectedPane: SettingsPane { SettingsPane(persisted: selectedPaneID) }
        #endif

        var premiumSection = PremiumSection.State()
        var diagnosticsReportFlow = DiagnosticsReportFlow.State()
        #if os(macOS)
        var showObservedFolderPicker = false
        #endif

        let appStoreUrl = URL(string: "https://apps.apple.com/app/pdf-archiver/id1433801905")!
        let pdfArchiverWebsiteUrl = URL(string: "https://pdf-archiver.io")!
        let termsOfUseUrl = URL(string: "https://pdf-archiver.io/terms")!
    }

    @Dependency(\.openURL) var openURL
    @Dependency(\.archiveStore) var archiveStore

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case onAboutMeTapped
        case onAdvancedSettingsTapped
        case onAppleIntelligenceSettingsTapped
        case diagnosticsReportFlow(DiagnosticsReportFlow.Action)
        case onImprintTapped
        case onLegalTapped
        #if os(macOS)
        case onObserveredFolderSelectedTapped
        case onObservedFolderRemoveTapped
        case onPaneSelected(SettingsPane)
        case onSettingsWindowAppeared
        case onSettingsWindowDisappeared
        #endif
        case onOpenPdfArchiverWebsiteTapped
        case onPremiumTapped
        case onShowArchiveTypeSelectionTapped
        case onPrivacyTapped
        case onSearchIndexTapped
        case onTermsOfUseTapped
        case premiumSection(PremiumSection.Action)
        #if os(macOS)
        case updateObservedFolder(URL?)
        #endif

        enum Delegate: Equatable {
            case showDocuments(SearchToken)
        }
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(\.premiumSection, action: \.premiumSection) {
            PremiumSection()
        }
        Scope(\.diagnosticsReportFlow, action: \.diagnosticsReportFlow) {
            DiagnosticsReportFlow()
        }
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .delegate:
                return .none

            case .destination(.presented(.searchIndex(.delegate(.showDocuments(let token))))):
                return .send(.delegate(.showDocuments(token)))

            case .destination:
                return .none

            case .onAboutMeTapped:
                state.destination = .aboutMe
                return .none

            case .onAdvancedSettingsTapped:
                state.destination = .expertSettings(ExpertSettings.State())
                return .none

            case .onAppleIntelligenceSettingsTapped:
                state.destination = .appleIntelligenceSettings(AppleIntelligenceSettings.State())
                return .none

            case .onSearchIndexTapped:
                state.destination = .searchIndex(SearchIndexSettings.State())
                return .none

            case .diagnosticsReportFlow:
                return .none

            case .onImprintTapped:
                state.destination = .imprint
                return .none

            case .onLegalTapped:
                state.destination = .legal
                return .none

            #if os(macOS)
            case .onObserveredFolderSelectedTapped:
                state.showObservedFolderPicker = true
                return .none

            case .onObservedFolderRemoveTapped:
                return .send(.updateObservedFolder(nil))

            case .onPaneSelected(let pane):
                state.$selectedPaneID.withLock { $0 = pane.rawValue }
                Self.openPane(pane, in: &state)
                return .none

            case .onSettingsWindowAppeared:
                Self.openPane(state.selectedPane, in: &state)
                return .none

            case .onSettingsWindowDisappeared:
                // The Settings scene's state outlives its window, and `SearchIndexSettings.State`
                // holds a live `@Fetch` — dropping the destination closes that query.
                state.destination = nil
                return .none
            #endif

            case .onOpenPdfArchiverWebsiteTapped:
                return .openExternalURL(state.pdfArchiverWebsiteUrl, with: openURL)

            case .onPremiumTapped:
                state.destination = .premium
                return .none

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

            #if os(macOS)
            case .updateObservedFolder(let url):
                state.showObservedFolderPicker = false
                state.$observedFolderURL.withLock { $0 = url }

                return .run { _ in
                    try await archiveStore.reloadDocuments()
                }
            #endif
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    #if os(macOS)
    private static func openPane(_ pane: SettingsPane, in state: inout State) {
        switch pane {
        case .storage: state.destination = .archiveStorage(StorageSelection.State())
        case .appleIntelligence: state.destination = .appleIntelligenceSettings(AppleIntelligenceSettings.State())
        case .searchIndex: state.destination = .searchIndex(SearchIndexSettings.State())
        case .advanced: state.destination = .expertSettings(ExpertSettings.State())

        // General, Premium and About are rendered from `Settings.State` itself.
        case .general, .premium, .about: state.destination = nil
        }
    }
    #endif
}

extension Settings.Destination.State: Sendable, Equatable {}

struct SettingsView: View {
    @Bindable var store: StoreOf<Settings>

    @Environment(\.requestReview) private var requestReview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                preferences
                aboutSection
            }
            // since we have buttons, we have to "fake" the foreground color - it would be the accent color otherwise
            .foregroundColor(.primary)
            .navigationTitle(Text("Preferences & More", bundle: #bundle))
#if os(iOS)
            .navigationViewStyle(StackNavigationViewStyle())
            .navigationBarTitleDisplayMode(.inline)
#endif
            .navigationDestination(item: $store.destination) { destination in
                switch destination {
                case .appleIntelligenceSettings:
                    if let appleIntelligenceSettingsStore = store.scope(\.destination?.appleIntelligenceSettings, action: \.destination.appleIntelligenceSettings) {
                        AppleIntelligenceSettingsView(store: appleIntelligenceSettingsStore)
                            .navigationTitle(Text("Apple Intelligence", bundle: #bundle))
                    } else {
                        preconditionFailure("Failed to load Apple Intelligence settings")
                    }

                case .archiveStorage:
                    if let storageSelectionStore = store.scope(\.destination?.archiveStorage, action: \.destination.archiveStorage) {
                        StorageSelectionView(store: storageSelectionStore)
                            .navigationTitle(Text("Storage", bundle: #bundle))
                    } else {
                        preconditionFailure("Failed to load export nothing found")
                    }

                case .expertSettings:
                    if let expertSettingsStore = store.scope(\.destination?.expertSettings, action: \.destination.expertSettings) {
                        ExpertSettingsView(store: expertSettingsStore)
                            .navigationTitle(Text("Advanced", bundle: #bundle))
                    } else {
                        preconditionFailure("Failed to load export nothing found")
                    }

                case .searchIndex:
                    if let searchIndexStore = store.scope(\.destination?.searchIndex, action: \.destination.searchIndex) {
                        SearchIndexSettingsView(store: searchIndexStore)
                            .navigationTitle(Text("Search Index", bundle: #bundle))
                    } else {
                        preconditionFailure("Failed to load the search index settings")
                    }

                case .premium:
                    Form {
                        PremiumSectionView(store: store.scope(\.premiumSection, action: \.premiumSection))
                    }
                    // Same as the root form: the buttons would take the accent color otherwise.
                    .foregroundColor(.primary)
                    .navigationTitle(Text("Premium", bundle: #bundle))

                case .aboutMe:
                    AboutMeView()

                case .legal:
                    Form {
                        Section {
                            LegalView(store: store)
                        }
                    }
                        .navigationTitle(Text("Legal", bundle: #bundle))

                case .termsOfUse:
                    let content = String(localized: "TERMS_OF_USE", bundle: #bundle)
                    MarkdownView(markdown: content)
                        .navigationTitle(String(localized: "Terms of Use", bundle: #bundle))

                case .privacy:
                    let content = String(localized: "PRIVACY", bundle: #bundle)
                    MarkdownView(markdown: content)
                        .navigationTitle(String(localized: "Privacy", bundle: #bundle))

                case .imprint:
                    let content = String(localized: "IMPRINT", bundle: #bundle)
                    MarkdownView(markdown: content)
                        .navigationTitle(Text("Imprint", bundle: #bundle))
                }
            }
        }
        .id(store.navigationStackID)
    }

    @ViewBuilder
    private var preferences: some View {
        Section {
            Picker(selection: Binding(store.$pdfQuality), label: Label(String(localized: "PDF Quality", bundle: #bundle), systemImage: "text.document")) {
                ForEach(PDFQuality.allCases, id: \.self) { quality in
                    quality.pickerLabel
                }
            }

            Button {
                store.send(.onShowArchiveTypeSelectionTapped)
            } label: {
                HStack {
                    Label(String(localized: "Storage", bundle: #bundle), systemImage: "externaldrive")
                    Spacer()
                    Text(store.selectedArchiveType.getPath().title, bundle: #bundle)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                store.send(.onAppleIntelligenceSettingsTapped)
            } label: {
                Label(String(localized: "Apple Intelligence", bundle: #bundle), systemImage: "apple.intelligence")
            }

            Button {
                store.send(.onSearchIndexTapped)
            } label: {
                Label(String(localized: "Search Index", bundle: #bundle), systemImage: "magnifyingglass.circle")
            }

            Button {
                store.send(.onAdvancedSettingsTapped)
            } label: {
                Label(String(localized: "Advanced", bundle: #bundle), systemImage: "gearshape.2")
            }

            Button {
                store.send(.onPremiumTapped)
            } label: {
                Label(String(localized: "Premium", bundle: #bundle), systemImage: "star.hexagon")
            }
        } header: {
            Text("Preferences", bundle: #bundle)
                .foregroundStyle(Color.secondary)
        }
    }

    private var aboutSection: some View {
        Section {
            Button {
                store.send(.diagnosticsReportFlow(.start()))
            } label: {
                HStack {
                    Label(String(localized: "Contact & Help", bundle: #bundle), systemImage: "envelope")
                    Spacer()
                    if store.diagnosticsReportFlow.isCreatingReport {
                        ProgressView()
                    }
                }
            }
            .diagnosticsReportFlow(store: store.scope(state: \.diagnosticsReportFlow, action: \.diagnosticsReportFlow))

            Button {
                requestReview()
            } label: {
                Label(String(localized: "Rate App", bundle: #bundle), systemImage: "app.gift.fill")
            }

            ShareLink(item: store.appStoreUrl) {
                Label(String(localized: "Share App", bundle: #bundle), systemImage: "square.and.arrow.up")
            }

            Button {
                store.send(.onLegalTapped)
            } label: {
                Label(String(localized: "Legal", bundle: #bundle), systemImage: "checkmark.seal.text.page")
            }
        } header: {
            Text("About", bundle: #bundle)
                .foregroundStyle(Color.secondary)
        }
    }
}

#if os(macOS)
#Preview("Settings", traits: .fixedLayout(width: 800, height: 600)) {
    SettingsView(
        store: Store(initialState: Settings.State()) {
            Settings()
                ._printChanges()
        }
    )
}

#endif
