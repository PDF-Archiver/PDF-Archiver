//
//  Settings.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 30.06.25.
//

import ArchiverModels
import ArchiverStore
import ComposableArchitecture
import Diagnostics
import Shared
import StoreKit
import SwiftUI
#if os(iOS)
import MessageUI
#endif
import OSLog
import UniformTypeIdentifiers

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
            Text("Synchronized - Your documents are stored in iCloud Drive. They are available to you on all devices with the same iCloud account, e.g. iPhone, iPad and Mac.", bundle: #bundle)

        #if !os(macOS)
        case .appContainer:
            VStack(alignment: .leading) {
                Text("Not synchronized - your documents are only stored locally in this app. They can be transferred via the Finder on a Mac, for example.", bundle: #bundle)
                // swiftlint:disable:next force_unwrapping
                Link("https://support.apple.com/en-us/HT210598", destination: URL(string: NSLocalizedString("https://support.apple.com/en-us/HT210598", comment: ""))!)
            }
        #endif

        case .local:
            Text("Not synchronized - Your documents are stored in a folder you choose on your computer. PDF Archiver does not initiate synchronization.", bundle: #bundle)
        }
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
        case privacy
        case searchIndex(SearchIndexSettings)
        case termsOfUse
    }

    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?

        @Shared(.pdfQuality) var pdfQuality: PDFQuality
        @SharedReader(.archivePathType) var selectedArchiveType: StorageType?
        #if os(macOS)
        @Shared(.observedFolder) var observedFolderURL: URL?
        #endif

        var premiumSection = PremiumSection.State()
        var isShowingMailSheet = false
        var isShowingDiagnosticsReportConsent = false
        var diagnosticsReport: DiagnosticsReport?
        var isCreatingDiagnosticsReport = false
        var didConfirmSendingDiagnosticsReport = false
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
        case destination(PresentationAction<Destination.Action>)
        case onAboutMeTapped
        case onAdvancedSettingsTapped
        case onAppleIntelligenceSettingsTapped
        case onContactSupportTapped
        case diagnosticsReportCreated(DiagnosticsReport)
        case onImprintTapped
        case onLegalTapped
        #if os(macOS)
        case onObserveredFolderSelectedTapped
        case onObservedFolderRemoveTapped
        #endif
        case onOpenPdfArchiverWebsiteTapped
        case onShowArchiveTypeSelectionTapped
        case onPrivacyTapped
        case onSearchIndexTapped
        case onSendWithReportTapped
        case onSendWithoutReportTapped
        case onCancelContactSupportTapped
        case onTermsOfUseTapped
        case premiumSection(PremiumSection.Action)
        #if os(macOS)
        case updateObservedFolder(URL?)
        #endif
    }

    private enum CancelID {
        case diagnosticsReport
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(\.premiumSection, action: \.premiumSection) {
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

            case .onAppleIntelligenceSettingsTapped:
                state.destination = .appleIntelligenceSettings(AppleIntelligenceSettings.State())
                return .none

            case .onSearchIndexTapped:
                state.destination = .searchIndex(SearchIndexSettings.State())
                return .none

            case .onContactSupportTapped:
                // Every tap reports the state at that moment, so the mail never carries the report
                // an earlier tap in the same session produced.
                state.diagnosticsReport = nil
                state.isCreatingDiagnosticsReport = true
                state.didConfirmSendingDiagnosticsReport = false
                // The consent dialog goes up right away and the report keeps loading behind it,
                // so the button never looks dead while the user decides.
                state.isShowingDiagnosticsReportConsent = true
                return .run { send in
                    // Logged before the report reads the log, so a report from a long-running
                    // session still carries the current state and not only the one from launch.
                    await AppStateLog.log()
                    let report = await Self.makeDiagnosticsReport()
                    await send(.diagnosticsReportCreated(report))
                }
                .cancellable(id: CancelID.diagnosticsReport)

            case .diagnosticsReportCreated(let report):
                state.diagnosticsReport = report
                state.isCreatingDiagnosticsReport = false
                if state.didConfirmSendingDiagnosticsReport {
                    Self.deliverDiagnosticsReport(report, state: &state)
                }
                return .none

            case .onSendWithReportTapped:
                state.didConfirmSendingDiagnosticsReport = true
                // The report may already be ready by the time consent is given; if it isn't,
                // `diagnosticsReportCreated` delivers it once loading finishes.
                if let report = state.diagnosticsReport {
                    Self.deliverDiagnosticsReport(report, state: &state)
                }
                return .none

            case .onSendWithoutReportTapped:
                // No need to wait for the report at all, so this delivers immediately and
                // drops whatever the background load already produced.
                state.diagnosticsReport = nil
                state.isCreatingDiagnosticsReport = false
                state.didConfirmSendingDiagnosticsReport = false
                Self.deliverDiagnosticsReport(nil, state: &state)
                return .cancel(id: CancelID.diagnosticsReport)

            case .onCancelContactSupportTapped:
                state.diagnosticsReport = nil
                state.isCreatingDiagnosticsReport = false
                state.didConfirmSendingDiagnosticsReport = false
                return .cancel(id: CancelID.diagnosticsReport)

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
            #endif

            case .onOpenPdfArchiverWebsiteTapped:
                #if os(iOS) || DEBUG
                return .run { [pdfArchiverWebsiteUrl = state.pdfArchiverWebsiteUrl] _ in
                    await openURL(pdfArchiverWebsiteUrl)
                }
                #else
                NSWorkspace.shared.open(state.pdfArchiverWebsiteUrl)
                return .none
                #endif

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
}

extension Settings {
    static func makeDiagnosticsReport() async -> DiagnosticsReport {
        await DiagnosticsReporter.create(
            using: [DiagnosticsReporter.DefaultReporter.generalInfo.reporter,
                    DiagnosticsReporter.DefaultReporter.appSystemMetadata.reporter,
                    OSLogReporter()],
            filters: [SensitivePathFilter.self]
        )
    }

    static func deliverDiagnosticsReport(_ report: DiagnosticsReport?, state: inout State) {
        #if os(iOS)
        state.isShowingMailSheet = true
        #endif
        #if os(macOS)
        sendReportOnMac(report)
        #endif
    }

    #if os(macOS)
    static func writeReportToTemporaryFile(_ report: DiagnosticsReport) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(report.filename)
        do {
            try report.data.write(to: url)
            return url
        } catch {
            Logger.settings.errorAndAssert("Failed to write diagnostics report", metadata: ["error": "\(LogRedact.describe(error))"])
            return nil
        }
    }

    /// Attaches the report via the Mail compose service; falls back to a plain `mailto:` link
    /// (no attachment) for a `nil` report, when no mail client is configured, or when the write fails
    /// (also revealing the report in Finder in that last case).
    static func sendReportOnMac(_ report: DiagnosticsReport?) {
        guard let report, let url = writeReportToTemporaryFile(report) else {
            openMailtoFallback()
            return
        }

        let service = NSSharingService(named: .composeEmail)
        service?.recipients = [Constants.mailRecipient]
        service?.subject = Constants.mailSubject
        guard let service, service.canPerform(withItems: [url]) else {
            openMailtoFallback()
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return
        }
        service.perform(withItems: [url])
    }

    static func openMailtoFallback() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Constants.mailRecipient
        components.queryItems = [URLQueryItem(name: "subject", value: Constants.mailSubject)]
        guard let url = components.url else {
            Logger.settings.errorAndAssert("Failed to create mailto url")
            return
        }
        NSWorkspace.shared.open(url)
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
                PremiumSectionView(store: store.scope(\.premiumSection, action: \.premiumSection))
                aboutSection
            }
            // since we have buttons, we have to "fake" the foreground color - it would be the accent color otherwise
            .foregroundColor(.primary)
            .navigationTitle(Text("Preferences & More", bundle: #bundle))
#if os(iOS)
            .navigationViewStyle(StackNavigationViewStyle())
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $store.isShowingMailSheet) {
                if !MFMailComposeViewController.canSendMail() {
                    Text("Mail is not configured on this device", bundle: #bundle)
                        .padding()
                } else {
                    // Only presented once the consent decision is final, so the report to attach
                    // (or `nil`, for "Without Report") is already settled.
                    MailComposeView(
                        isShowing: $store.isShowingMailSheet,
                        recipient: Constants.mailRecipient,
                        subject: Constants.mailSubject,
                        report: store.diagnosticsReport
                    )
                }
            }
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
    }

    @ViewBuilder
    private var preferences: some View {
        Section {
            Picker(selection: Binding(store.$pdfQuality), label: Label(String(localized: "PDF Quality", bundle: #bundle), systemImage: "text.document")) {
                ForEach(PDFQuality.allCases, id: \.self) { quality in
                    Text(quality.name, bundle: #bundle)
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
        } header: {
            Text("Preferences", bundle: #bundle)
                .foregroundStyle(Color.secondary)
        }
    }

    private var aboutSection: some View {
        Section {
            Button {
                store.send(.onContactSupportTapped)
            } label: {
                HStack {
                    Label(String(localized: "Contact & Help", bundle: #bundle), systemImage: "envelope")
                    Spacer()
                    if store.isCreatingDiagnosticsReport {
                        ProgressView()
                    }
                }
            }
            .diagnosticsReportConsentDialog(
                isPresented: $store.isShowingDiagnosticsReportConsent,
                onSendWithReport: { store.send(.onSendWithReportTapped) },
                onSendWithoutReport: { store.send(.onSendWithoutReportTapped) },
                onCancel: { store.send(.onCancelContactSupportTapped) }
            )

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
struct SettingsMacView: View {
    @Bindable var store: StoreOf<Settings>

    @Environment(\.requestReview) private var requestReview

    var body: some View {
        NavigationStack {
            TabView {
                Tab(String(localized: "General", bundle: #bundle), systemImage: "gear") {
                    generalPreferences
                        .focusable(false)
                }

                Tab(String(localized: "Premium", bundle: #bundle), systemImage: "star.hexagon") {
                    PremiumSectionView(store: store.scope(\.premiumSection, action: \.premiumSection))
                        .padding(.horizontal)
                        .focusable(false)
                }

                Tab(String(localized: "About", bundle: #bundle), systemImage: "info.circle") {
                    aboutPreferences
                        .focusable(false)
                }
            }
            .tabViewStyle(.tabBarOnly)
        }
        .frame(width: 400, height: 350)
        .sheet(isPresented: Binding(
            get: { store.destination != nil },
            set: { if !$0 { store.destination = nil } }
        )) {
            if let destination = store.destination {
                NavigationStack {
                    Group {
                        switch destination {
                        case .appleIntelligenceSettings:
                            if let appleIntelligenceSettingsStore = store.scope(\.destination?.appleIntelligenceSettings, action: \.destination.appleIntelligenceSettings) {
                                AppleIntelligenceSettingsView(store: appleIntelligenceSettingsStore)
                                    .navigationTitle(Text("Apple Intelligence", bundle: #bundle))
                            }

                        case .archiveStorage:
                            if let storageSelectionStore = store.scope(\.destination?.archiveStorage, action: \.destination.archiveStorage) {
                                StorageSelectionView(store: storageSelectionStore)
                                    .navigationTitle(Text("Storage", bundle: #bundle))
                            }

                        case .expertSettings:
                            if let expertSettingsStore = store.scope(\.destination?.expertSettings, action: \.destination.expertSettings) {
                                ExpertSettingsView(store: expertSettingsStore)
                                    .navigationTitle(Text("Advanced", bundle: #bundle))
                            }

                        case .searchIndex:
                            if let searchIndexStore = store.scope(\.destination?.searchIndex, action: \.destination.searchIndex) {
                                SearchIndexSettingsView(store: searchIndexStore)
                                    .navigationTitle(Text("Search Index", bundle: #bundle))
                            }

                        case .aboutMe:
                            AboutMeView()

                        case .legal:
                            LegalView(store: store)
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
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(String(localized: "Done", bundle: #bundle)) {
                                store.destination = nil
                            }
                        }
                    }
                    .frame(minWidth: 500, minHeight: 400)
                }
            }
        }
        .fileImporter(isPresented: $store.showObservedFolderPicker, allowedContentTypes: [UTType.folder], onCompletion: { result in
            switch result {
            case .success(let url):
                // Securely access the URL to save a bookmark
                guard url.startAccessingSecurityScopedResource() else {
                    // Handle the failure here.
                    return
                }
                store.send(.updateObservedFolder(url))

            case .failure(let error):
                Logger.settings.faultAndAssert("Failed to import a local folder: \(LogRedact.describe(error))")
                NotificationCenter.default.postAlert(error)
            }
        })
    }

    @ViewBuilder
    private var generalPreferences: some View {
        Form {
            Section {
                LabeledContent {
                    Picker("", selection: Binding(store.$pdfQuality)) {
                        ForEach(PDFQuality.allCases, id: \.self) { quality in
                            Text(quality.name, bundle: #bundle)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                } label: {
                    Label(String(localized: "PDF Quality", bundle: #bundle), systemImage: "text.document")
                }

                LabeledContent {
                    HStack {
                        Text(store.selectedArchiveType.getPath().title, bundle: #bundle)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(String(localized: "Change…", bundle: #bundle)) {
                            store.send(.onShowArchiveTypeSelectionTapped)
                        }
                    }
                } label: {
                    Label(String(localized: "Storage", bundle: #bundle), systemImage: "externaldrive")
                }

                LabeledContent {
                    HStack(spacing: 6) {
                        if let observedFolderURL = store.observedFolderURL {
                            Text(observedFolderURL.path)
                            Button {
                                store.send(.onObservedFolderRemoveTapped)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Button(String(localized: "Select", bundle: #bundle)) {
                                store.send(.onObserveredFolderSelectedTapped)
                            }
                        }
                    }
                } label: {
                    Label(String(localized: "Observed Folder", bundle: #bundle), systemImage: "folder.badge.plus")
                }

                LabeledContent {
                    Button(String(localized: "Configure…", bundle: #bundle)) {
                        store.send(.onAppleIntelligenceSettingsTapped)
                    }
                } label: {
                    Label(String(localized: "Apple Intelligence", bundle: #bundle), systemImage: "apple.intelligence")
                }

                LabeledContent {
                    Button(String(localized: "Configure…", bundle: #bundle)) {
                        store.send(.onSearchIndexTapped)
                    }
                } label: {
                    Label(String(localized: "Search Index", bundle: #bundle), systemImage: "magnifyingglass.circle")
                }

                LabeledContent {
                    Button(String(localized: "Configure…", bundle: #bundle)) {
                        store.send(.onAdvancedSettingsTapped)
                    }
                } label: {
                    Label(String(localized: "Advanced", bundle: #bundle), systemImage: "gearshape.2")
                }
            } header: {
                Text("Preferences", bundle: #bundle)
                    .foregroundStyle(Color.secondary)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var aboutPreferences: some View {
        Form {
            Section {
                Button {
                    store.send(.onContactSupportTapped)
                } label: {
                    HStack {
                        Label(String(localized: "Contact & Help", bundle: #bundle), systemImage: "envelope")
                        Spacer()
                        if store.isCreatingDiagnosticsReport {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .diagnosticsReportConsentDialog(
                    isPresented: $store.isShowingDiagnosticsReportConsent,
                    onSendWithReport: { store.send(.onSendWithReportTapped) },
                    onSendWithoutReport: { store.send(.onSendWithoutReportTapped) },
                    onCancel: { store.send(.onCancelContactSupportTapped) }
                )

                Button {
                    requestReview()
                } label: {
                    HStack {
                        Label(String(localized: "Rate App", bundle: #bundle), systemImage: "app.gift.fill")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ShareLink(item: store.appStoreUrl) {
                    HStack {
                        Label(String(localized: "Share App", bundle: #bundle), systemImage: "square.and.arrow.up")
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text("About", bundle: #bundle)
                    .foregroundStyle(Color.secondary)
            }
            Section {
                LegalView(store: store)
            } header: {
                Text("Legal", bundle: #bundle)
                    .foregroundStyle(Color.secondary)
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
