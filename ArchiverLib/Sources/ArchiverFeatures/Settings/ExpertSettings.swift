//
//  ExpertSettings.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 30.06.25.
//

import ArchiverDatabase
import ArchiverModels
import ComposableArchitecture
import Shared
import SQLiteData
import SwiftUI

@Reducer
struct ExpertSettings {

    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Action.Alert>?

        @Shared(.notSaveDocumentTagsAsPDFMetadata)
        var notSaveDocumentTagsAsPDFMetadata: Bool

        @Shared(.documentTagsNotRequired)
        var documentTagsNotRequired: Bool

        @Shared(.documentSpecificationNotRequired)
        var documentSpecificationNotRequired: Bool

        @Shared(.multiTagSelectionDelayEnabled)
        var multiTagSelectionDelayEnabled: Bool

        @Shared(.ocrEnabled)
        var ocrEnabled: Bool

        @Shared(.highlightDetectedDateEnabled)
        var highlightDetectedDateEnabled: Bool

        @Shared(.downloadAllForSearch)
        var downloadAllForSearch: Bool

        @SharedReader(.premiumStatus)
        var premiumStatus: PremiumStatus = .loading

        @Fetch(DocumentIndexState.StatusRequest()) var searchIndexStatus = DocumentIndexState.Status()
    }

    enum Action: BindableAction, Equatable {
        case alert(PresentationAction<Alert>)
        case binding(BindingAction<State>)
        case onClearTempFolderTapped
        #if !os(macOS)
        case onShowPermissionsTapped
        #endif
        case onResetAppTapped
        case onRebuildSearchIndexTapped

        enum Alert: Equatable {
            case confirmClearTempFolder
            case confirmRebuildSearchIndex
            case resetCompleted
        }
    }

    @Dependency(\.archiveIndexer) var archiveIndexer
    @Dependency(\.archiveStore) var archiveStore
    @Dependency(\.openURL) var openURL
    @Dependency(\.fileManager) var fileManager
    @Dependency(\.userDefaultsManager) var userDefaultsManager
    @Dependency(\.notificationCenter) var notificationCenter

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .alert(.presented(.confirmClearTempFolder)):
                try? fileManager.removeItemAt(Constants.tempDocumentURL)
                return .none

            case .alert(.presented(.confirmRebuildSearchIndex)):
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

            case .onClearTempFolderTapped:
                state.alert = AlertState {
                    TextState("Clear Temp Folder", bundle: #bundle)
                } actions: {
                    ButtonState(role: .destructive, action: .confirmClearTempFolder) {
                        TextState("Clear", bundle: #bundle)
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel", bundle: #bundle)
                    }
                } message: {
                    TextState("This removes all unprocessed documents from the temporary import folder. Documents already in your inbox or archive are not affected.", bundle: #bundle)
                }
                return .none

            #if !os(macOS)
            case .onShowPermissionsTapped:
                guard let settingsAppURL = URL(string: UIApplication.openSettingsURLString) else { fatalError("Could not find settings url!") }
                return .run { _ in
                    await openURL(settingsAppURL)
                }
            #endif

            case .onRebuildSearchIndexTapped:
                state.alert = AlertState {
                    TextState("Rebuild Search Index", bundle: #bundle)
                } actions: {
                    ButtonState(action: .confirmRebuildSearchIndex) {
                        TextState("Rebuild", bundle: #bundle)
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel", bundle: #bundle)
                    }
                } message: {
                    TextState("Your document list comes back within seconds. Searching inside documents is rebuilt in the background while your device is charging.", bundle: #bundle)
                }
                return .none

            case .onResetAppTapped:
                // remove all temporary files
                try? fileManager.removeItemAt(Constants.tempDocumentURL)

                // remove all user defaults
                userDefaultsManager.reset()

                // Show alert to inform user about restart requirement
                state.alert = AlertState {
                    TextState("Reset App", bundle: #bundle)
                } actions: {
                    ButtonState(action: .resetCompleted) {
                        TextState("OK", bundle: #bundle)
                    }
                } message: {
                    TextState("Please restart the app to complete the reset.", bundle: #bundle)
                }
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

struct ExpertSettingsView: View {
    @Bindable var store: StoreOf<ExpertSettings>

    var body: some View {
        Form {
            Toggle(String(localized: "Save Tags in PDF Metadata", bundle: #bundle), isOn: Binding(store.$notSaveDocumentTagsAsPDFMetadata).flipped)
            Toggle(String(localized: "Require Document Tags", bundle: #bundle), isOn: Binding(store.$documentTagsNotRequired).flipped)
            Toggle(String(localized: "Require Document Specification", bundle: #bundle), isOn: Binding(store.$documentSpecificationNotRequired).flipped)
            Toggle(String(localized: "Multi-Tag Selection Delay", bundle: #bundle), isOn: Binding(store.$multiTagSelectionDelayEnabled))
            Toggle(String(localized: "Automatic OCR for Image PDFs", bundle: #bundle), isOn: Binding(store.$ocrEnabled))
            Toggle(String(localized: "Highlight Detected Date", bundle: #bundle), isOn: Binding(store.$highlightDetectedDateEnabled))

            Section {
                if store.premiumStatus == .active {
                    LabeledContent(String(localized: "Indexed", bundle: #bundle), value: "\(store.searchIndexStatus.indexed)")
                    LabeledContent(String(localized: "Pending", bundle: #bundle), value: "\(store.searchIndexStatus.pending)")
                    LabeledContent(String(localized: "Not Downloaded", bundle: #bundle), value: "\(store.searchIndexStatus.notDownloaded)")
                    if let lastRun = store.searchIndexStatus.lastRun {
                        LabeledContent(String(localized: "Last Run", bundle: #bundle)) {
                            Text(lastRun, format: .relative(presentation: .named))
                        }
                    }
                } else {
                    Text("Searching inside documents requires Premium.", bundle: #bundle)
                        .foregroundStyle(.secondary)
                }

                Toggle(String(localized: "Download All Documents for Search", bundle: #bundle), isOn: Binding(store.$downloadAllForSearch))
                    .disabled(store.premiumStatus != .active)

                Button {
                    store.send(.onRebuildSearchIndexTapped)
                } label: {
                    Text("Rebuild Search Index", bundle: #bundle)
                }
            } header: {
                Text("Search Index", bundle: #bundle)
            }
            #if !os(macOS)
            Button {
                store.send(.onShowPermissionsTapped)
            } label: {
                Text("Show Permissions", bundle: #bundle)
            }
            #endif

            Section {
                Button {
                    store.send(.onClearTempFolderTapped)
                } label: {
                    Text("Clear Temp Folder", bundle: #bundle)
                }

                Button {
                    store.send(.onResetAppTapped)
                } label: {
                    Text("Reset App Preferences", bundle: #bundle)
                }
            }
        }
        .foregroundStyle(.primary)
        .alert($store.scope(\.$alert, action: \.alert))
    }
}

#Preview("ExpertSettings", traits: .fixedLayout(width: 800, height: 600)) {
    ExpertSettingsView(
        store: Store(initialState: ExpertSettings.State()) {
            ExpertSettings()
                ._printChanges()
        }
    )
}
