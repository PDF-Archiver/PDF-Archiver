//
//  AppleIntelligenceSettings.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 15.10.25.
//

import ArchiverModels
import ComposableArchitecture
import ContentExtractorStore
import Shared
import SwiftUI

@Reducer
struct AppleIntelligenceSettings {
    static let maxCustomPromptLength = 1000

    @ObservableState
    struct State: Equatable {
        var availability: AppleIntelligenceAvailability = .operatingSystemNotCompatible

        @Shared(.appleIntelligenceEnabled)
        var appleIntelligenceEnabled: Bool

        @Shared(.appleIntelligenceCustomPrompt)
        var customPrompt: String?

        @Shared(.appleIntelligenceCacheEnabled)
        var cacheEnabled: Bool

        @Shared(.backgroundCacheNotificationsEnabled)
        var backgroundNotificationsEnabled: Bool

        var cacheEntryCount: Int = 0
        var isClearingCache: Bool = false
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case availabilityLoaded(AppleIntelligenceAvailability)
        case cacheCountLoaded(Int)
        case clearCacheTapped
        case cacheCleared
    }

    @Dependency(\.contentExtractorStore) var contentExtractorStore

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.$cacheEnabled):
                return .run { [enabled = state.cacheEnabled] _ in
                    await contentExtractorStore.setCacheEnabled(enabled)
                }

            case .binding:
                return .none

            case .onAppear:
                return .run { send in
                    let availability = await contentExtractorStore.isAvailable()
                    await send(.availabilityLoaded(availability))

                    let cacheCount = await contentExtractorStore.getCacheCount()
                    await send(.cacheCountLoaded(cacheCount))
                }

            case let .availabilityLoaded(availability):
                state.availability = availability
                return .none

            case let .cacheCountLoaded(count):
                state.cacheEntryCount = count
                return .none

            case .clearCacheTapped:
                state.isClearingCache = true
                return .run { send in
                    await contentExtractorStore.clearCache()
                    await send(.cacheCleared)
                }

            case .cacheCleared:
                state.isClearingCache = false
                state.cacheEntryCount = 0
                return .none
            }
        }
    }
}

struct AppleIntelligenceSettingsView: View {
    @Bindable var store: StoreOf<AppleIntelligenceSettings>

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text("Apple Intelligence", bundle: .module)
                            .font(.headline)
                    } icon: {
                        Image(systemName: "apple.intelligence")
                            .foregroundStyle(.blue)
                    }
                }

                LabeledContent(String(localized: "Status", bundle: .module)) {
                    availabilityView
                }

                if store.availability == .available {
                    Toggle(
                        String(localized: "Use Apple Intelligence", bundle: .module),
                        isOn: $store.appleIntelligenceEnabled
                    )
                }
            } footer: {
                if store.availability == .available {
                    Text("When enabled, Apple Intelligence will automatically suggest descriptions and tags for your documents. However, this feature may take some time to function.\nIn case of a failure, the non-AI version will always be used.", bundle: .module)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }

            if store.availability == .available {
                Section {
                    TextField(String(localized: "Custom Prompt", bundle: .module),
                              text: Binding(
                                get: { store.customPrompt ?? "" },
                                set: { newValue in
                                    let trimmed = String(newValue.prefix(AppleIntelligenceSettings.maxCustomPromptLength))
                                    store.customPrompt = trimmed.isEmpty ? nil : trimmed
                                }
                              ),
                              prompt: Text("Optional: Enter your custom prompt additions", bundle: .module),
                              axis: .vertical)
                    .lineLimit(1...)

                } footer: {
                    Text("\(store.customPrompt?.count ?? 0) / \(AppleIntelligenceSettings.maxCustomPromptLength)", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section {
                    LabeledContent(String(localized: "Cache Entries", bundle: .module)) {
                        Text("\(store.cacheEntryCount)")
                            .foregroundStyle(.secondary)
                    }

                    Toggle(
                        String(localized: "Use Cache", bundle: .module),
                        isOn: $store.cacheEnabled
                    )

                    if store.cacheEnabled {
                        Toggle(
                            String(localized: "Background Processing Notifications", bundle: .module),
                            isOn: $store.backgroundNotificationsEnabled
                        )
                    }

                    Button(role: .destructive) {
                        store.send(.clearCacheTapped)
                    } label: {
                        if store.isClearingCache {
                            HStack {
                                Text("Clearing Cache...", bundle: .module)
                                ProgressView()
                                    .controlSize(.small)
                            }
                        } else {
                            Text("Clear Cache", bundle: .module)
                        }
                    }
                    .disabled(store.isClearingCache || store.cacheEntryCount == 0)

                } footer: {
                    Text("Cache improves performance by storing previously analyzed documents. Cached entries are stored locally and not synced across devices. The system may automatically remove cache files when storage is needed.\n\nWhen background notifications are enabled, you'll receive alerts about cache processing, including duration and number of caches created.", bundle: .module)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }
        }
        .formStyle(.grouped)
        .foregroundStyle(.primary)
        .onAppear {
            store.send(.onAppear)
        }
    }

    @ViewBuilder
    private var availabilityView: some View {
        switch store.availability {
        case .available:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("Available", bundle: .module)
                    .font(.subheadline)
            }
            .foregroundStyle(.green)
        case .deviceNotCompatible:
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                Text("Device Not Compatible", bundle: .module)
                    .font(.subheadline)
            }
            .foregroundStyle(.red)
        case .unavailable:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                Text("Unavailable", bundle: .module)
                    .font(.subheadline)
            }
            .foregroundStyle(.orange)
        case .operatingSystemNotCompatible:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                    Text("Operating System Not Compatible", bundle: .module)
                        .font(.subheadline)
                }
                .foregroundStyle(.red)

                Text("Apple Intelligence requires iOS/macOS 26 or later. Please update your device to use this feature.", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("AppleIntelligenceSettings - Available", traits: .fixedLayout(width: 800, height: 600)) {
    AppleIntelligenceSettingsView(
        store: Store(
            initialState: AppleIntelligenceSettings.State(availability: .available)
        ) {
            AppleIntelligenceSettings()
        } withDependencies: {
            $0.contentExtractorStore.isAvailable = { .available }
        }
    )
}

#Preview("AppleIntelligenceSettings - Device Not Compatible", traits: .fixedLayout(width: 800, height: 600)) {
    AppleIntelligenceSettingsView(
        store: Store(
            initialState: AppleIntelligenceSettings.State(availability: .deviceNotCompatible)
        ) {
            AppleIntelligenceSettings()
        } withDependencies: {
            $0.contentExtractorStore.isAvailable = { .deviceNotCompatible }
        }
    )
}

#Preview("AppleIntelligenceSettings - OS Not Compatible", traits: .fixedLayout(width: 800, height: 600)) {
    AppleIntelligenceSettingsView(
        store: Store(
            initialState: AppleIntelligenceSettings.State(availability: .operatingSystemNotCompatible)
        ) {
            AppleIntelligenceSettings()
        } withDependencies: {
            $0.contentExtractorStore.isAvailable = { .operatingSystemNotCompatible }
        }
    )
}

#Preview("AppleIntelligenceSettings - Unavailable", traits: .fixedLayout(width: 800, height: 600)) {
    AppleIntelligenceSettingsView(
        store: Store(
            initialState: AppleIntelligenceSettings.State(availability: .unavailable)
        ) {
            AppleIntelligenceSettings()
        } withDependencies: {
            $0.contentExtractorStore.isAvailable = { .unavailable }
        }
    )
}
