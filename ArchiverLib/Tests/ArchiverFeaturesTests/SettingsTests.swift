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
        #expect(PDFQuality.good.name == "75% - Good (Default)")
        #expect(PDFQuality.normal.name == "50% - Normal")
        #expect(PDFQuality.small.name == "25% - Small")
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

    // MARK: - Mail Sheet Tests

    @Test
    func showMailSheet() async throws {
        let store = TestStore(initialState: Settings.State()) {
            Settings()
        }

        await store.send(.binding(.set(\.isShowingMailSheet, true))) {
            $0.isShowingMailSheet = true
        }
    }

    @Test
    func hideMailSheet() async throws {
        let store = TestStore(initialState: Settings.State(isShowingMailSheet: true)) {
            Settings()
        }

        await store.send(.binding(.set(\.isShowingMailSheet, false))) {
            $0.isShowingMailSheet = false
        }
    }

    // MARK: - Diagnostics Report Tests

    @Test
    func contactSupportShowsTheConsentDialogImmediatelyWithoutWaitingForTheReport() async throws {
        let report = DiagnosticsReport(filename: "Diagnostics-Report.html", data: Data())
        let store = TestStore(initialState: Settings.State(diagnosticsReport: report)) {
            Settings()
        } withDependencies: {
            // The reducer's effect logs the app state before creating the report, which reads this.
            $0.archiveIndexer.pendingTextCount = { 0 }
        }
        store.exhaustivity = .off

        await store.send(.onContactSupportTapped) {
            $0.diagnosticsReport = nil
            $0.isCreatingDiagnosticsReport = true
            $0.isShowingDiagnosticsReportConsent = true
        }

        await store.finish()
    }

    @Test
    func sendWithReportTappedConfirmsSendingWhileTheReportIsStillLoading() async throws {
        let store = TestStore(initialState: Settings.State()) {
            Settings()
        }

        await store.send(.onSendWithReportTapped) {
            $0.didConfirmSendingDiagnosticsReport = true
        }
    }

    // `deliverDiagnosticsReport` calls the real, unmocked `NSSharingService`/`mailto:` handoff on
    // macOS, so only iOS - where delivery is just a state flag - exercises the "already ready" path.
    #if os(iOS)
    @Test
    func sendWithReportTappedOpensTheMailSheetWhenTheReportIsAlreadyReady() async throws {
        let report = DiagnosticsReport(filename: "Diagnostics-Report.html", data: Data())
        let store = TestStore(initialState: Settings.State(diagnosticsReport: report)) {
            Settings()
        }

        await store.send(.onSendWithReportTapped) {
            $0.didConfirmSendingDiagnosticsReport = true
            $0.isShowingMailSheet = true
        }
    }

    @Test
    func sendWithoutReportTappedOpensTheMailSheetImmediatelyWithoutTheReport() async throws {
        let report = DiagnosticsReport(filename: "Diagnostics-Report.html", data: Data())
        let store = TestStore(initialState: Settings.State(
            diagnosticsReport: report,
            isCreatingDiagnosticsReport: true
        )) {
            Settings()
        }

        await store.send(.onSendWithoutReportTapped) {
            $0.diagnosticsReport = nil
            $0.isCreatingDiagnosticsReport = false
            $0.isShowingMailSheet = true
        }
    }
    #endif

    @Test
    func cancelContactSupportTappedDiscardsTheReport() async throws {
        let report = DiagnosticsReport(filename: "Diagnostics-Report.html", data: Data())
        let store = TestStore(initialState: Settings.State(
            isShowingDiagnosticsReportConsent: true,
            diagnosticsReport: report,
            isCreatingDiagnosticsReport: true
        )) {
            Settings()
        }

        await store.send(.onCancelContactSupportTapped) {
            $0.diagnosticsReport = nil
            $0.isCreatingDiagnosticsReport = false
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
        #expect(state.isShowingMailSheet == false)
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
        #expect(state1.isShowingMailSheet == state2.isShowingMailSheet)
        #expect(state1.destination == state2.destination)
    }

    @Test
    func stateInequality() throws {
        let state1 = Settings.State(isShowingMailSheet: false)
        let state2 = Settings.State(isShowingMailSheet: true)

        #expect(state1.isShowingMailSheet != state2.isShowingMailSheet)
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
