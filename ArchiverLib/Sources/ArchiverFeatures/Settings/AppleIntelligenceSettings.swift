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
        var availability: AppleIntelligenceAvailability = .deviceNotCompatible

        @Shared(.appleIntelligenceEnabled)
        var appleIntelligenceEnabled: Bool

        @Shared(.appleIntelligenceCustomPrompt)
        var customPrompt: String?
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case availabilityLoaded(AppleIntelligenceAvailability)
    }

    @Dependency(\.contentExtractorStore) var contentExtractorStore

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .run { send in
                    let availability = await contentExtractorStore.isAvailable()
                    await send(.availabilityLoaded(availability))
                }

            case let .availabilityLoaded(availability):
                state.availability = availability
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
        HStack {
            Text("Status:", bundle: .module)
                .font(.subheadline)
                .foregroundStyle(.secondary)

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

#Preview("AppleIntelligenceSettings - Not Compatible", traits: .fixedLayout(width: 800, height: 600)) {
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
