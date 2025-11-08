import ArchiverModels
import ComposableArchitecture
import ContentExtractorStore
import Foundation
import Testing

@testable import ArchiverFeatures

@MainActor
struct AppleIntelligenceSettingsTests {
    // MARK: - State Initialization Tests

    @Test
    func defaultStateInitialization() async throws {
        let state = AppleIntelligenceSettings.State()

        #expect(state.availability == .operatingSystemNotCompatible)
        #expect(state.cacheEntryCount == 0)
        #expect(state.isClearingCache == false)
    }

    @Test
    func stateInitializationWithAvailability() async throws {
        let state = AppleIntelligenceSettings.State(availability: .available)

        #expect(state.availability == .available)
        #expect(state.cacheEntryCount == 0)
        #expect(state.isClearingCache == false)
    }

    // MARK: - Availability Tests

    @Test
    func availabilityStates() async throws {
        #expect(AppleIntelligenceAvailability.available.isUsable == true)
        #expect(AppleIntelligenceAvailability.unavailable.isUsable == false)
        #expect(AppleIntelligenceAvailability.deviceNotCompatible.isUsable == false)
        #expect(AppleIntelligenceAvailability.operatingSystemNotCompatible.isUsable == false)
    }

    @Test
    func loadAvailability() async throws {
        let store = TestStore(initialState: AppleIntelligenceSettings.State()) {
            AppleIntelligenceSettings()
        } withDependencies: {
            $0.contentExtractorStore.isAvailable = { .available }
            $0.contentExtractorStore.getCacheCount = { 0 }
        }

        await store.send(.availabilityLoaded(.available)) {
            $0.availability = .available
        }
    }

    @Test
    func loadDeviceNotCompatible() async throws {
        let store = TestStore(initialState: AppleIntelligenceSettings.State()) {
            AppleIntelligenceSettings()
        } withDependencies: {
            $0.contentExtractorStore.isAvailable = { .deviceNotCompatible }
            $0.contentExtractorStore.getCacheCount = { 0 }
        }

        await store.send(.availabilityLoaded(.deviceNotCompatible)) {
            $0.availability = .deviceNotCompatible
        }
    }

    @Test
    func loadUnavailable() async throws {
        let store = TestStore(initialState: AppleIntelligenceSettings.State()) {
            AppleIntelligenceSettings()
        } withDependencies: {
            $0.contentExtractorStore.isAvailable = { .unavailable }
            $0.contentExtractorStore.getCacheCount = { 0 }
        }

        await store.send(.availabilityLoaded(.unavailable)) {
            $0.availability = .unavailable
        }
    }

    @Test
    func loadOperatingSystemNotCompatible() async throws {
        let store = TestStore(
            initialState: AppleIntelligenceSettings.State(availability: .available)
        ) {
            AppleIntelligenceSettings()
        } withDependencies: {
            $0.contentExtractorStore.isAvailable = { .operatingSystemNotCompatible }
            $0.contentExtractorStore.getCacheCount = { 0 }
        }

        await store.send(.availabilityLoaded(.operatingSystemNotCompatible)) {
            $0.availability = .operatingSystemNotCompatible
        }
    }

    // MARK: - OnAppear Tests

    @Test
    func onAppearLoadsAvailabilityAndCacheCount() async throws {
        let store = TestStore(initialState: AppleIntelligenceSettings.State()) {
            AppleIntelligenceSettings()
        } withDependencies: {
            $0.contentExtractorStore.isAvailable = { .available }
            $0.contentExtractorStore.getCacheCount = { 42 }
        }

        await store.send(.onAppear)
        await store.receive(.availabilityLoaded(.available)) {
            $0.availability = .available
        }
        await store.receive(.cacheCountLoaded(42)) {
            $0.cacheEntryCount = 42
        }
    }

    @Test
    func onAppearWithZeroCacheCount() async throws {
        let store = TestStore(
            initialState: AppleIntelligenceSettings.State(
                availability: .available,
                cacheEntryCount: 10
            )
        ) {
            AppleIntelligenceSettings()
        } withDependencies: {
            $0.contentExtractorStore.isAvailable = { .deviceNotCompatible }
            $0.contentExtractorStore.getCacheCount = { 0 }
        }

        await store.send(.onAppear)
        await store.receive(.availabilityLoaded(.deviceNotCompatible)) {
            $0.availability = .deviceNotCompatible
        }
        await store.receive(.cacheCountLoaded(0)) {
            $0.cacheEntryCount = 0
        }
    }

    // MARK: - Cache Count Tests

    @Test
    func cacheCountLoaded() async throws {
        let store = TestStore(initialState: AppleIntelligenceSettings.State()) {
            AppleIntelligenceSettings()
        } withDependencies: {
            $0.contentExtractorStore.getCacheCount = { 100 }
        }

        await store.send(.cacheCountLoaded(100)) {
            $0.cacheEntryCount = 100
        }
    }

    @Test
    func cacheCountLoadedZero() async throws {
        let store = TestStore(initialState: AppleIntelligenceSettings.State(cacheEntryCount: 50)) {
            AppleIntelligenceSettings()
        }

        await store.send(.cacheCountLoaded(0)) {
            $0.cacheEntryCount = 0
        }
    }

    // MARK: - Cache Clearing Tests

    @Test
    func clearCacheTappedFlow() async throws {
        let store = TestStore(
            initialState: AppleIntelligenceSettings.State(
                availability: .available,
                cacheEntryCount: 10
            )
        ) {
            AppleIntelligenceSettings()
        } withDependencies: {
            $0.contentExtractorStore.clearCache = {}
        }

        await store.send(.clearCacheTapped) {
            $0.isClearingCache = true
        }
        await store.receive(.cacheCleared) {
            $0.isClearingCache = false
            $0.cacheEntryCount = 0
        }
    }

    @Test
    func cacheCleared() async throws {
        let store = TestStore(
            initialState: AppleIntelligenceSettings.State(
                cacheEntryCount: 50,
                isClearingCache: true
            )
        ) {
            AppleIntelligenceSettings()
        }

        await store.send(.cacheCleared) {
            $0.isClearingCache = false
            $0.cacheEntryCount = 0
        }
    }

    // MARK: - Binding Tests

    @Test
    func bindingAppleIntelligenceEnabled() async throws {
        let store = TestStore(
            initialState: AppleIntelligenceSettings.State(availability: .available)
        ) {
            AppleIntelligenceSettings()
        }

        await store.send(.binding(.set(\.appleIntelligenceEnabled, true))) {
            $0.$appleIntelligenceEnabled.withLock { $0 = true }
        }

        await store.send(.binding(.set(\.appleIntelligenceEnabled, false))) {
            $0.$appleIntelligenceEnabled.withLock { $0 = false }
        }
    }

    @Test
    func bindingCacheEnabled() async throws {
        let store = TestStore(
            initialState: AppleIntelligenceSettings.State(availability: .available)
        ) {
            AppleIntelligenceSettings()
        } withDependencies: {
            $0.contentExtractorStore.setCacheEnabled = { _ in }
        }

        await store.send(.binding(.set(\.cacheEnabled, true))) {
            $0.$cacheEnabled.withLock { $0 = true }
        }
    }

    @Test
    func bindingCacheDisabled() async throws {
        let store = TestStore(
            initialState: AppleIntelligenceSettings.State(availability: .available)
        ) {
            AppleIntelligenceSettings()
        } withDependencies: {
            $0.contentExtractorStore.setCacheEnabled = { _ in }
        }

        await store.send(.binding(.set(\.cacheEnabled, false))) {
            $0.$cacheEnabled.withLock { $0 = false }
        }
    }

    @Test
    func bindingBackgroundNotificationsEnabled() async throws {
        let store = TestStore(
            initialState: AppleIntelligenceSettings.State(availability: .available)
        ) {
            AppleIntelligenceSettings()
        }

        await store.send(.binding(.set(\.backgroundNotificationsEnabled, true))) {
            $0.$backgroundNotificationsEnabled.withLock { $0 = true }
        }

        await store.send(.binding(.set(\.backgroundNotificationsEnabled, false))) {
            $0.$backgroundNotificationsEnabled.withLock { $0 = false }
        }
    }

    @Test
    func bindingCustomPrompt() async throws {
        let store = TestStore(
            initialState: AppleIntelligenceSettings.State(availability: .available)
        ) {
            AppleIntelligenceSettings()
        }

        await store.send(.binding(.set(\.customPrompt, "test prompt"))) {
            $0.$customPrompt.withLock { $0 = "test prompt" }
        }
    }

    @Test
    func bindingCustomPromptNil() async throws {
        let store = TestStore(
            initialState: AppleIntelligenceSettings.State(availability: .available)
        ) {
            AppleIntelligenceSettings()
        }

        await store.send(.binding(.set(\.customPrompt, nil))) {
            $0.$customPrompt.withLock { $0 = nil }
        }
    }

    // MARK: - Custom Prompt Length Tests

    @Test
    func maxCustomPromptLengthConstant() async throws {
        #expect(AppleIntelligenceSettings.maxCustomPromptLength == 1000)
    }

    @Test
    func customPromptWithinLimit() async throws {
        let prompt = String(repeating: "a", count: 999)
        let store = TestStore(
            initialState: AppleIntelligenceSettings.State(availability: .available)
        ) {
            AppleIntelligenceSettings()
        }

        await store.send(.binding(.set(\.customPrompt, prompt))) {
            $0.$customPrompt.withLock { $0 = prompt }
        }
    }

    @Test
    func customPromptAtMaxLimit() async throws {
        let prompt = String(repeating: "a", count: 1000)
        let store = TestStore(
            initialState: AppleIntelligenceSettings.State(availability: .available)
        ) {
            AppleIntelligenceSettings()
        }

        await store.send(.binding(.set(\.customPrompt, prompt))) {
            $0.$customPrompt.withLock { $0 = prompt }
        }
    }

    // MARK: - State Equality Tests

    @Test
    func stateEquality() async throws {
        let state1 = AppleIntelligenceSettings.State(
            availability: .available,
            cacheEntryCount: 10
        )
        let state2 = AppleIntelligenceSettings.State(
            availability: .available,
            cacheEntryCount: 10
        )

        #expect(state1.availability == state2.availability)
        #expect(state1.cacheEntryCount == state2.cacheEntryCount)
        #expect(state1.isClearingCache == state2.isClearingCache)
    }

    @Test
    func stateInequality() async throws {
        let state1 = AppleIntelligenceSettings.State(
            availability: .available,
            cacheEntryCount: 10
        )
        let state2 = AppleIntelligenceSettings.State(
            availability: .unavailable,
            cacheEntryCount: 20
        )

        #expect(state1.availability != state2.availability)
        #expect(state1.cacheEntryCount != state2.cacheEntryCount)
    }

    // MARK: - Integration Tests

    @Test
    func fullClearCacheWorkflow() async throws {
        let store = TestStore(
            initialState: AppleIntelligenceSettings.State(
                availability: .available,
                cacheEntryCount: 100
            )
        ) {
            AppleIntelligenceSettings()
        } withDependencies: {
            $0.contentExtractorStore.clearCache = {}
            $0.contentExtractorStore.getCacheCount = { 0 }
        }

        // User taps clear cache button
        await store.send(.clearCacheTapped) {
            $0.isClearingCache = true
        }

        // Cache is cleared
        await store.receive(.cacheCleared) {
            $0.isClearingCache = false
            $0.cacheEntryCount = 0
        }
    }

    @Test
    func fullOnAppearWorkflow() async throws {
        let store = TestStore(
            initialState: AppleIntelligenceSettings.State()
        ) {
            AppleIntelligenceSettings()
        } withDependencies: {
            $0.contentExtractorStore.isAvailable = { .available }
            $0.contentExtractorStore.getCacheCount = { 25 }
        }

        // View appears
        await store.send(.onAppear)

        // Availability is loaded
        await store.receive(.availabilityLoaded(.available)) {
            $0.availability = .available
        }

        // Cache count is loaded
        await store.receive(.cacheCountLoaded(25)) {
            $0.cacheEntryCount = 25
        }
    }

    @Test
    func toggleCacheAndClearWorkflow() async throws {
        let store = TestStore(
            initialState: AppleIntelligenceSettings.State(
                availability: .available,
                cacheEntryCount: 50
            )
        ) {
            AppleIntelligenceSettings()
        } withDependencies: {
            $0.contentExtractorStore.setCacheEnabled = { _ in }
            $0.contentExtractorStore.clearCache = {}
        }

        // Enable cache
        await store.send(.binding(.set(\.cacheEnabled, true))) {
            $0.$cacheEnabled.withLock { $0 = true }
        }

        // Clear cache
        await store.send(.clearCacheTapped) {
            $0.isClearingCache = true
        }
        await store.receive(.cacheCleared) {
            $0.isClearingCache = false
            $0.cacheEntryCount = 0
        }
    }
}
