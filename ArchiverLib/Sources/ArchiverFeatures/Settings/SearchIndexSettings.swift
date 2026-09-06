//
//  SearchIndexSettings.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverDatabase
import ArchiverModels
import ComposableArchitecture
import Shared
import SQLiteData
import SwiftUI

@Reducer
struct SearchIndexSettings {

    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Action.Alert>?

        @Shared(.downloadAllForSearch)
        var downloadAllForSearch: Bool

        @SharedReader(.premiumStatus)
        var premiumStatus: PremiumStatus = .loading

        @Fetch(DocumentIndexState.StatusRequest()) var status = DocumentIndexState.Status()
    }

    enum Action: BindableAction, Equatable {
        case alert(PresentationAction<Alert>)
        case binding(BindingAction<State>)
        case onRebuildTapped

        enum Alert: Equatable {
            case confirmRebuild
        }
    }

    @Dependency(\.archiveIndexer) var archiveIndexer
    @Dependency(\.archiveStore) var archiveStore

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .alert(.presented(.confirmRebuild)):
                return .run { _ in
                    await archiveIndexer.requestRebuild()
                    // The providers deliver a full snapshot within seconds, so the list is back
                    // almost immediately; the text index follows in the background.
                    try await archiveStore.reloadDocuments()
                }

            case .alert:
                return .none

            case .binding:
                return .none

            case .onRebuildTapped:
                state.alert = AlertState {
                    TextState("Rebuild Search Index", bundle: #bundle)
                } actions: {
                    ButtonState(action: .confirmRebuild) {
                        TextState("Rebuild", bundle: #bundle)
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel", bundle: #bundle)
                    }
                } message: {
                    TextState("Your document list comes back within seconds. Searching inside documents is rebuilt in the background while your device is charging.", bundle: #bundle)
                }
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

struct SearchIndexSettingsView: View {
    @Bindable var store: StoreOf<SearchIndexSettings>

    var body: some View {
        Form {
            Section {
                if store.premiumStatus == .active {
                    progress
                    counts
                } else {
                    Text("Searching inside documents requires Premium.", bundle: #bundle)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Documents without a text layer are skipped and are not scanned again.", bundle: #bundle)
            }

            Section {
                Toggle(String(localized: "Download All Documents for Search", bundle: #bundle), isOn: Binding(store.$downloadAllForSearch))
                    .disabled(store.premiumStatus != .active)

                Button {
                    store.send(.onRebuildTapped)
                } label: {
                    Text("Rebuild Search Index", bundle: #bundle)
                }
            }
        }
        .foregroundStyle(.primary)
        .alert($store.scope(\.$alert, action: \.alert))
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(store.status.indexed) of \(store.status.total) documents indexed", bundle: #bundle)
            ProgressView(value: Double(store.status.indexed), total: Double(max(store.status.total, 1)))
        }
    }

    @ViewBuilder
    private var counts: some View {
        // Only what is left to explain: a zero row is noise, and the line above already says how
        // far the index has come.
        if store.status.withoutText > 0 {
            LabeledContent(String(localized: "Without Text", bundle: #bundle), value: "\(store.status.withoutText)")
        }
        if store.status.pending > 0 {
            LabeledContent(String(localized: "Pending", bundle: #bundle), value: "\(store.status.pending)")
        }
        if store.status.notDownloaded > 0 {
            LabeledContent(String(localized: "Not Downloaded", bundle: #bundle), value: "\(store.status.notDownloaded)")
        }
        if store.status.failed > 0 {
            LabeledContent(String(localized: "Failed", bundle: #bundle), value: "\(store.status.failed)")
        }
        if let lastRun = store.status.lastRun {
            LabeledContent(String(localized: "Last Run", bundle: #bundle)) {
                Text(lastRun, format: .relative(presentation: .named))
            }
        }
    }
}

#Preview("SearchIndexSettings", traits: .fixedLayout(width: 500, height: 400)) {
    SearchIndexSettingsView(
        store: Store(initialState: SearchIndexSettings.State()) {
            SearchIndexSettings()
        }
    )
}
