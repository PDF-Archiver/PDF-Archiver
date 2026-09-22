//
//  SettingsMacView.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.09.26.
//

#if os(macOS)
import ComposableArchitecture
import SwiftUI

struct SettingsMacView: View {
    @Bindable var store: StoreOf<Settings>

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: paneSelection) { pane in
                Label { Text(pane.title, bundle: #bundle) } icon: { Image(systemName: pane.symbol) }
                    .tag(pane)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            // `.id` recreates the stack per pane, so a page pushed inside one pane (Legal's
            // links, the About link) does not survive a sidebar switch to another pane.
            NavigationStack {
                paneBody
                    .navigationTitle(Text(store.selectedPane.title, bundle: #bundle))
            }
            .id(store.selectedPane)
        }
        .frame(minWidth: 680, idealWidth: 720, minHeight: 460, idealHeight: 520)
        .onAppear { store.send(.onSettingsWindowAppeared) }
        .onDisappear { store.send(.onSettingsWindowDisappeared) }
    }

    private var paneSelection: Binding<SettingsPane?> {
        Binding(
            get: { store.selectedPane },
            set: { store.send(.onPaneSelected($0 ?? .general)) }
        )
    }

    @ViewBuilder
    private var paneBody: some View {
        switch store.selectedPane {
        case .general:
            GeneralPane(store: store)

        case .about:
            AboutPane(store: store)

        case .premium:
            Form {
                PremiumSectionView(store: store.scope(\.premiumSection, action: \.premiumSection))
            }
            .formStyle(.grouped)

        case .storage:
            if let storageSelectionStore = store.scope(\.destination?.archiveStorage, action: \.destination.archiveStorage) {
                StorageSelectionView(store: storageSelectionStore)
            } else {
                EmptyView()
            }

        case .appleIntelligence:
            if let appleIntelligenceSettingsStore = store.scope(\.destination?.appleIntelligenceSettings, action: \.destination.appleIntelligenceSettings) {
                AppleIntelligenceSettingsView(store: appleIntelligenceSettingsStore)
            } else {
                EmptyView()
            }

        case .searchIndex:
            if let searchIndexStore = store.scope(\.destination?.searchIndex, action: \.destination.searchIndex) {
                SearchIndexSettingsView(store: searchIndexStore)
            } else {
                EmptyView()
            }

        case .advanced:
            if let expertSettingsStore = store.scope(\.destination?.expertSettings, action: \.destination.expertSettings) {
                ExpertSettingsView(store: expertSettingsStore)
            } else {
                EmptyView()
            }
        }
    }
}

#Preview("Settings Mac", traits: .fixedLayout(width: 720, height: 520)) {
    SettingsMacView(
        store: Store(initialState: Settings.State()) {
            Settings()
                ._printChanges()
        }
    )
}

#Preview("Settings Mac - Advanced Pane", traits: .fixedLayout(width: 720, height: 520)) {
    NavigationStack {
        ExpertSettingsView(
            store: Store(initialState: ExpertSettings.State()) {
                ExpertSettings()
            }
        )
        .navigationTitle(Text(SettingsPane.advanced.title, bundle: #bundle))
    }
}
#endif
