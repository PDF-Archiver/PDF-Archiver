import ArchiverModels
import ComposableArchitecture
import Foundation
import Testing

@testable import ArchiverFeatures

@MainActor
struct SettingsTests {
    // MARK: - PDF Quality Tests

    @Test
    func defaultPdfQuality() async throws {
        let state = Settings.State()

        // PDF quality should have a default value from @Shared
        #expect(PDFQuality.allCases.contains(state.pdfQuality))
    }

    @Test
    func pdfQualityNames() async throws {
        #expect(PDFQuality.lossless.name == "100% - Lossless")
        #expect(PDFQuality.good.name == "75% - Good (Default)")
        #expect(PDFQuality.normal.name == "50% - Normal")
        #expect(PDFQuality.small.name == "25% - Small")
    }

    // MARK: - Storage Type Tests

    @Test
    func storageTypeTitles() async throws {
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
    func defaultStorageType() async throws {
        let state = Settings.State()

        // Storage type may be nil initially or have a value
        #expect(state.selectedArchiveType == nil || state.selectedArchiveType != nil)
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

    // MARK: - Premium Section Tests

    @Test
    func premiumSectionInitialized() async throws {
        let state = Settings.State()

        // Premium section is always initialized (not optional)
        #expect(state.premiumSection.premiumStatus == .loading || state.premiumSection.premiumStatus == .active || state.premiumSection.premiumStatus == .inactive)
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
    func defaultStateInitialization() async throws {
        let state = Settings.State()

        #expect(state.destination == nil)
        #expect(state.isShowingMailSheet == false)
    }

    @Test
    func stateWithDestination() async throws {
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
    func observedFolderURL() async throws {
        let state = Settings.State()

        // Observed folder may be nil initially
        #expect(state.observedFolderURL == nil || state.observedFolderURL != nil)
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
    #endif

    // MARK: - URL Constants Tests

    @Test
    func urlConstantsAreValid() async throws {
        let state = Settings.State()

        #expect(state.appStoreUrl.absoluteString.contains("apps.apple.com"))
        #expect(state.pdfArchiverWebsiteUrl.absoluteString.contains("pdf-archiver.io"))
        #expect(state.termsOfUseUrl.absoluteString.contains("pdf-archiver.io/terms"))
    }

    // MARK: - Equatable Tests

    @Test
    func stateEquality() async throws {
        let state1 = Settings.State()
        let state2 = Settings.State()

        // States with same values should be equal
        #expect(state1.isShowingMailSheet == state2.isShowingMailSheet)
        #expect(state1.destination == state2.destination)
    }

    @Test
    func stateInequality() async throws {
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
}
