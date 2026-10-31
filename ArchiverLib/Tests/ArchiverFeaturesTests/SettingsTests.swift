import ArchiverDatabase
import ArchiverModels
import ComposableArchitecture
import Dependencies
import DependenciesTestSupport
import Diagnostics
import Foundation
import SQLiteData
import Testing

@testable import ArchiverFeatures

@MainActor
@Suite(.dependencies { try $0.bootstrapDatabase() })
struct SettingsTests {
    // MARK: - PDF Quality Tests

    @Test
    func defaultPdfQuality() throws {
        let state = Settings.State()

        // PDF quality should have a default value from @Shared
        #expect(PDFQuality.allCases.contains(state.pdfQuality))
    }

    @Test
    func pdfQualityNames() throws {
        #expect(PDFQuality.lossless.name == "100% - Lossless")
        #expect(PDFQuality.good.name == "75% - Good")
        #expect(PDFQuality.normal.name == "50% - Normal")
        #expect(PDFQuality.small.name == "25% - Small")
    }

    /// The picker marks the quality the stored key falls back to, not a case named by hand - the
    /// two drifted apart once already.
    @Test
    func theDefaultPdfQualityComesFromTheStoredKey() throws {
        #expect(PDFQuality.default == .lossless)
    }

    // MARK: - Storage Type Tests

    @Test
    func storageTypeTitles() throws {
        #if os(macOS)
        #expect(StorageType.iCloudDrive.title == "iCloud Drive")
        #expect(StorageType.local(URL(fileURLWithPath: "/test")).title == "Drive")
        #else
        #expect(StorageType.iCloudDrive.title == "iCloud Drive")
        #expect(StorageType.appContainer.title == "Local")
        #expect(StorageType.local(URL(fileURLWithPath: "/test")).title == "Folder")
        #endif
    }

    @Test
    func defaultStorageType() throws {
        let state = Settings.State()

        #expect(state.selectedArchiveType == nil)
    }

    // MARK: - Navigation Tests

    @Test
    func navigateToAboutMe() async throws {
        let store = TestStore(initialState: Settings.State()) {
            Settings()
        }

        await store.send(.onAboutMeTapped) {
            $0.destination = .aboutMe
        }
    }

    @Test
    func navigateToLegal() async throws {
        let store = TestStore(initialState: Settings.State()) {
            Settings()
        }

        await store.send(.onLegalTapped) {
            $0.destination = .legal
        }
    }

    @Test
    func navigateToPrivacy() async throws {
        let store = TestStore(initialState: Settings.State()) {
            Settings()
        }

        await store.send(.onPrivacyTapped) {
            $0.destination = .privacy
        }
    }

    @Test
    func navigateToTermsOfUse() async throws {
        let store = TestStore(initialState: Settings.State()) {
            Settings()
        }

        await store.send(.onTermsOfUseTapped) {
            $0.destination = .termsOfUse
        }
    }

    @Test
    func navigateToImprint() async throws {
        let store = TestStore(initialState: Settings.State()) {
            Settings()
        }

        await store.send(.onImprintTapped) {
            $0.destination = .imprint
        }
    }

    // MARK: - Diagnostics Report Tests

    @Test
    func contactSupportShowsTheConsentDialogImmediatelyWithoutWaitingForTheReport() async throws {
        let report = DiagnosticsReport(filename: "Diagnostics-Report.html", data: Data())
        var initialState = Settings.State()
        initialState.diagnosticsReportFlow.report = report
        let store = TestStore(initialState: initialState) {
            Settings()
        } withDependencies: {
            $0.diagnosticsMail.createReport = { report }
        }

        await store.send(.diagnosticsReportFlow(.start())) {
            $0.diagnosticsReportFlow.report = nil
            $0.diagnosticsReportFlow.isCreatingReport = true
            $0.diagnosticsReportFlow.isShowingConsent = true
        }
        await store.receive(\.diagnosticsReportFlow.reportCreated) {
            $0.diagnosticsReportFlow.report = report
            $0.diagnosticsReportFlow.isCreatingReport = false
        }
    }

    @Test
    func sendWithReportTappedConfirmsSendingWhileTheReportIsStillLoading() async throws {
        let store = TestStore(initialState: Settings.State()) {
            Settings()
        }

        await store.send(.diagnosticsReportFlow(.sendWithReportTapped)) {
            $0.diagnosticsReportFlow.didConfirmSending = true
        }
    }

    @Test
    func sendWithReportTappedDeliversTheMailWhenTheReportIsAlreadyReady() async throws {
        let report = DiagnosticsReport(filename: "Diagnostics-Report.html", data: Data())
        let deliveredMails = LockIsolated<[DiagnosticsMail]>([])
        var initialState = Settings.State()
        initialState.diagnosticsReportFlow.report = report
        let store = TestStore(initialState: initialState) {
            Settings()
        } withDependencies: {
            $0.diagnosticsMail.send = { mail in
                deliveredMails.withValue { $0.append(mail) }
                return true
            }
        }

        await store.send(.diagnosticsReportFlow(.sendWithReportTapped)) {
            $0.diagnosticsReportFlow.didConfirmSending = true
            #if os(iOS)
            $0.diagnosticsReportFlow.isShowingMailSheet = true
            #endif
        }
        #if os(macOS)
        await store.receive(\.diagnosticsReportFlow.mailFinished)
        await store.receive(\.diagnosticsReportFlow.delegate.mailSent)
        #endif
        await store.finish()

        #if os(iOS)
        #expect(store.state.diagnosticsReportFlow.mail == DiagnosticsMail(report: report, extraAttachments: []))
        #else
        #expect(deliveredMails.value == [DiagnosticsMail(report: report, extraAttachments: [])])
        #endif
    }

    @Test
    func sendWithoutReportTappedDeliversTheMailImmediatelyWithoutTheReport() async throws {
        let report = DiagnosticsReport(filename: "Diagnostics-Report.html", data: Data())
        let deliveredMails = LockIsolated<[DiagnosticsMail]>([])
        var initialState = Settings.State()
        initialState.diagnosticsReportFlow.report = report
        initialState.diagnosticsReportFlow.isCreatingReport = true
        let store = TestStore(initialState: initialState) {
            Settings()
        } withDependencies: {
            // Nothing to attach, so macOS falls back to `mailto:` and the mail did not leave yet.
            $0.diagnosticsMail.send = { mail in
                deliveredMails.withValue { $0.append(mail) }
                return false
            }
        }

        await store.send(.diagnosticsReportFlow(.sendWithoutReportTapped)) {
            $0.diagnosticsReportFlow.report = nil
            $0.diagnosticsReportFlow.isCreatingReport = false
            #if os(iOS)
            $0.diagnosticsReportFlow.isShowingMailSheet = true
            #endif
        }
        #if os(macOS)
        await store.receive(\.diagnosticsReportFlow.mailFinished)
        #endif
        await store.finish()

        #if os(iOS)
        #expect(store.state.diagnosticsReportFlow.mail == DiagnosticsMail(report: nil, extraAttachments: []))
        #else
        #expect(deliveredMails.value == [DiagnosticsMail(report: nil, extraAttachments: [])])
        #endif
    }

    @Test
    func cancelContactSupportTappedDiscardsTheReport() async throws {
        let report = DiagnosticsReport(filename: "Diagnostics-Report.html", data: Data())
        var initialState = Settings.State()
        initialState.diagnosticsReportFlow.isShowingConsent = true
        initialState.diagnosticsReportFlow.report = report
        initialState.diagnosticsReportFlow.isCreatingReport = true
        let store = TestStore(initialState: initialState) {
            Settings()
        }

        await store.send(.diagnosticsReportFlow(.cancelTapped)) {
            $0.diagnosticsReportFlow.report = nil
            $0.diagnosticsReportFlow.isCreatingReport = false
        }
    }

    // MARK: - Premium Section Tests

    @Test
    func premiumSectionInitialized() throws {
        let state = Settings.State()

        #expect(state.premiumSection.premiumStatus == .loading)
    }

    @Test
    func premiumSectionShowManageSubscription() async throws {
        let openedURL = LockIsolated<URL?>(nil)

        let store = TestStore(initialState: Settings.State()) {
            Settings()
        } withDependencies: {
            $0.openURL = .init { [openedURL] url in
                openedURL.setValue(url)
                return true
            }
        }

        await store.send(.premiumSection(.showManageSubscription))

        // Verify the correct URL was opened
        #expect(openedURL.value?.absoluteString == "https://apps.apple.com/account/subscriptions")
    }

    // MARK: - State Initialization Tests

    @Test
    func defaultStateInitialization() throws {
        let state = Settings.State()

        #expect(state.destination == nil)
        #expect(state.diagnosticsReportFlow == DiagnosticsReportFlow.State())
    }

    @Test
    func stateWithDestination() throws {
        let state = Settings.State(destination: .legal)

        #expect(state.destination == .legal)
    }

    // MARK: - Binding Tests

    @Test
    func bindingPdfQuality() async throws {
        let store = TestStore(initialState: Settings.State()) {
            Settings()
        }

        await store.send(.binding(.set(\.pdfQuality, .lossless))) {
            $0.$pdfQuality.withLock { $0 = .lossless }
        }
    }

    // MARK: - macOS Specific Tests

    #if os(macOS)
    @Test
    func showObservedFolderPicker() async throws {
        let store = TestStore(initialState: Settings.State()) {
            Settings()
        }

        await store.send(.binding(.set(\.showObservedFolderPicker, true))) {
            $0.showObservedFolderPicker = true
        }
    }

    @Test
    func hideObservedFolderPicker() async throws {
        let store = TestStore(initialState: Settings.State(showObservedFolderPicker: true)) {
            Settings()
        }

        await store.send(.binding(.set(\.showObservedFolderPicker, false))) {
            $0.showObservedFolderPicker = false
        }
    }

    @Test
    func observedFolderURL() throws {
        let state = Settings.State()

        #expect(state.observedFolderURL == nil)
    }

    @Test
    func onObservedFolderSelectedTapped() async throws {
        let store = TestStore(initialState: Settings.State()) {
            Settings()
        }

        await store.send(.onObserveredFolderSelectedTapped) {
            $0.showObservedFolderPicker = true
        }
    }

    // MARK: - Settings Pane Tests

    @Test
    func onPaneSelectedOpensTheMatchingDestination() async throws {
        let store = TestStore(initialState: Settings.State()) {
            Settings()
        }

        await store.send(.onPaneSelected(.searchIndex)) {
            $0.$selectedPaneID.withLock { $0 = SettingsPane.searchIndex.rawValue }
            $0.destination = .searchIndex(SearchIndexSettings.State())
        }

        await store.send(.onPaneSelected(.storage)) {
            $0.$selectedPaneID.withLock { $0 = SettingsPane.storage.rawValue }
            $0.destination = .archiveStorage(StorageSelection.State())
        }

        await store.send(.onPaneSelected(.appleIntelligence)) {
            $0.$selectedPaneID.withLock { $0 = SettingsPane.appleIntelligence.rawValue }
            $0.destination = .appleIntelligenceSettings(AppleIntelligenceSettings.State())
        }

        await store.send(.onPaneSelected(.advanced)) {
            $0.$selectedPaneID.withLock { $0 = SettingsPane.advanced.rawValue }
            $0.destination = .expertSettings(ExpertSettings.State())
        }
    }

    @Test
    func onPaneSelectedClearsTheDestinationForPlainPanes() async throws {
        let store = TestStore(initialState: Settings.State(destination: .searchIndex(SearchIndexSettings.State()))) {
            Settings()
        }

        await store.send(.onPaneSelected(.about)) {
            $0.$selectedPaneID.withLock { $0 = SettingsPane.about.rawValue }
            $0.destination = nil
        }
    }

    @Test
    func settingsWindowAppearedRestoresThePersistedPane() async throws {
        var initialState = Settings.State()
        initialState.$selectedPaneID.withLock { $0 = "advanced" }

        let store = TestStore(initialState: initialState) {
            Settings()
        }

        await store.send(.onSettingsWindowAppeared) {
            $0.destination = .expertSettings(ExpertSettings.State())
        }
    }

    @Test
    func settingsWindowAppearedFallsBackToGeneral() async throws {
        var initialState = Settings.State()
        initialState.$selectedPaneID.withLock { $0 = "nonsense" }

        let store = TestStore(initialState: initialState) {
            Settings()
        }

        await store.send(.onSettingsWindowAppeared)

        #expect(store.state.destination == nil)
        #expect(store.state.selectedPane == .general)
    }

    @Test
    func settingsWindowDisappearedDropsTheDestination() async throws {
        let store = TestStore(initialState: Settings.State(destination: .searchIndex(SearchIndexSettings.State()))) {
            Settings()
        }

        await store.send(.onSettingsWindowDisappeared) {
            $0.destination = nil
        }
    }
    #endif

    // MARK: - URL Constants Tests

    @Test
    func urlConstantsAreValid() throws {
        let state = Settings.State()

        #expect(state.appStoreUrl.absoluteString.contains("apps.apple.com"))
        #expect(state.pdfArchiverWebsiteUrl.absoluteString.contains("pdf-archiver.io"))
        #expect(state.termsOfUseUrl.absoluteString.contains("pdf-archiver.io/terms"))
    }

    // MARK: - Equatable Tests

    @Test
    func stateEquality() throws {
        let state1 = Settings.State()
        let state2 = Settings.State()

        // States with same values should be equal
        #expect(state1 == state2)
    }

    @Test
    func stateInequality() throws {
        let state1 = Settings.State(destination: nil)
        let state2 = Settings.State(destination: .legal)

        #expect(state1 != state2)
    }

    // MARK: - Action Tests

    @Test
    func onShowArchiveTypeSelectionTapped() async throws {
        let store = TestStore(initialState: Settings.State()) {
            Settings()
        }

        await store.send(.onShowArchiveTypeSelectionTapped) {
            $0.destination = .archiveStorage(.init())
        }
    }

    @Test
    func onAdvancedSettingsTapped() async throws {
        let store = TestStore(initialState: Settings.State()) {
            Settings()
        }

        await store.send(.onAdvancedSettingsTapped) {
            $0.destination = .expertSettings(.init())
        }
    }

    @Test
    func onPremiumTapped() async throws {
        let store = TestStore(initialState: Settings.State()) {
            Settings()
        }

        await store.send(.onPremiumTapped) {
            $0.destination = .premium
        }
    }

    @Test
    func onAppleIntelligenceSettingsTapped() async throws {
        let store = TestStore(initialState: Settings.State()) {
            Settings()
        }

        await store.send(.onAppleIntelligenceSettingsTapped) {
            $0.destination = .appleIntelligenceSettings(.init())
        }
    }

    @Test
    func navigateToSearchIndex() async throws {
        let store = TestStore(initialState: Settings.State()) {
            Settings()
        }

        await store.send(.onSearchIndexTapped) {
            $0.destination = .searchIndex(SearchIndexSettings.State())
        }
    }
}
