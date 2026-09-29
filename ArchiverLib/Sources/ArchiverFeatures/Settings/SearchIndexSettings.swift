//
//  SearchIndexSettings.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import ArchiverDatabase
import ArchiverModels
import ArchiverStore
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

        @SharedReader(.searchIndexUnavailable)
        var searchIndexUnavailable: Bool

        @Fetch(DocumentIndexState.StatusRequest()) var status = DocumentIndexState.Status()
    }

    enum Action: BindableAction, Equatable {
        case alert(PresentationAction<Alert>)
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case onDocumentsTapped(SearchToken)
        case onRebuildTapped
        #if DEBUG
        /// Production downloads the archive from the background task only; this is how a run is
        /// reproduced while the app is open.
        case onDebugPrefetchTapped
        #endif

        enum Alert: Equatable {
            case confirmRebuild
        }

        @CasePathable
        enum Delegate: Equatable {
            case showDocuments(SearchToken)
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

            case .delegate:
                return .none

            case .onDocumentsTapped(let token):
                return .send(.delegate(.showDocuments(token)))

            #if DEBUG
            case .onDebugPrefetchTapped:
                return .run { _ in
                    await SearchIndexDownloads.requestNextBatch()
                }
            #endif

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
    #if os(macOS)
    @Environment(\.dismissWindow) private var dismissWindow
    #endif

    var body: some View {
        Form {
            // The only place a failed `bootstrapDatabase()` can reach the user: it runs in
            // `App.init()`, where no view is around to present an alert.
            if store.searchIndexUnavailable {
                Section {
                    Label {
                        Text("The search index could not be created. Rebuilding it may help.", bundle: #bundle)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
                if store.premiumStatus == .active {
                    progress
                    counts
                } else {
                    Text("Searching inside documents requires Premium.", bundle: #bundle)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Progress", bundle: #bundle)
            } footer: {
                Text("Documents without a text layer are skipped and are not scanned again.", bundle: #bundle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(String(localized: "Download All Documents for Search", bundle: #bundle), isOn: Binding(store.$downloadAllForSearch))
                    .disabled(store.premiumStatus != .active)
            } header: {
                Text("Downloads", bundle: #bundle)
            } footer: {
                Text("Only documents on this device can be scanned. The rest are downloaded in small batches while your device is charging.", bundle: #bundle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    store.send(.onRebuildTapped)
                } label: {
                    Text("Rebuild Search Index", bundle: #bundle)
                }
            }

            #if DEBUG
            Section {
                // Not localized on purpose: a debug-only label must stay out of the string catalog.
                Button(String("Download Next Batch Now")) {
                    store.send(.onDebugPrefetchTapped)
                }
            } header: {
                Text(verbatim: "Debug")
            }
            #endif
        }
        .formStyle(.grouped)
        .foregroundStyle(.primary)
        .alert($store.scope(\.$alert, action: \.alert))
    }

    private var progress: some View {
        ProgressView(value: Double(store.status.processed), total: Double(max(store.status.total, 1))) {
            Text("\(store.status.processed) of \(store.status.total) documents processed", bundle: #bundle)
        }
    }

    @ViewBuilder
    private var counts: some View {
        // Only what is left to explain: a zero row is noise, and the line above already says how
        // far the index has come.
        if store.status.withoutText > 0 {
            documentsButton(String(localized: "Without Text", bundle: #bundle), count: store.status.withoutText, token: .withoutText)
        }
        if store.status.pending > 0 {
            LabeledContent(String(localized: "Pending", bundle: #bundle), value: "\(store.status.pending)")
        }
        if store.status.notDownloaded > 0 {
            LabeledContent(String(localized: "Not Downloaded", bundle: #bundle), value: "\(store.status.notDownloaded)")
        }
        if store.status.failed > 0 {
            documentsButton(String(localized: "Failed", bundle: #bundle), count: store.status.failed, token: .indexFailed)
        }
        if let lastRun = store.status.lastRun {
            LabeledContent(String(localized: "Last Run", bundle: #bundle)) {
                Text(lastRun, format: .relative(presentation: .named))
            }
        }
    }

    private func documentsButton(_ title: String, count: Int, token: SearchToken) -> some View {
        Button {
            store.send(.onDocumentsTapped(token))
            #if os(macOS)
            // The filtered list opens in the main window, which this Settings window would cover.
            dismissWindow()
            #endif
        } label: {
            LabeledContent(title) {
                HStack {
                    Text(count, format: .number)
                    Image(systemName: "chevron.forward")
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview("SearchIndexSettings", traits: .fixedLayout(width: 500, height: 400)) {
    SearchIndexSettingsView(
        store: Store(initialState: SearchIndexSettings.State()) {
            SearchIndexSettings()
        }
    )
}
