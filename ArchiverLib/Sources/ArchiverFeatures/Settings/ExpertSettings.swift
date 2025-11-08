//
//  ExpertSettings.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 30.06.25.
//

import ComposableArchitecture
import Shared
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
    }

    enum Action: BindableAction, Equatable {
        case alert(PresentationAction<Alert>)
        case binding(BindingAction<State>)
        #if !os(macOS)
        case onShowPermissionsTapped
        #endif
        case onResetAppTapped

        enum Alert {
            case resetCompleted
        }
    }

    @Dependency(\.openURL) var openURL
    @Dependency(\.fileManager) var fileManager
    @Dependency(\.userDefaultsManager) var userDefaultsManager
    @Dependency(\.notificationCenter) var notificationCenter

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .alert:
                return .none

            case .binding:
                return .none

            #if !os(macOS)
            case .onShowPermissionsTapped:
                guard let settingsAppURL = URL(string: UIApplication.openSettingsURLString) else { fatalError("Could not find settings url!") }
                return .run { _ in
                    await openURL(settingsAppURL)
                }
            #endif

            case .onResetAppTapped:
                // remove all temporary files
                try? fileManager.removeItemAt(Constants.tempDocumentURL)

                // remove all user defaults
                userDefaultsManager.reset()

                // Show alert to inform user about restart requirement
                state.alert = AlertState {
                    TextState("Reset App", bundle: .module)
                } actions: {
                    ButtonState(action: .resetCompleted) {
                        TextState("OK", bundle: .module)
                    }
                } message: {
                    TextState("Please restart the app to complete the reset.", bundle: .module)
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
            Toggle(String(localized: "Save Tags in PDF Metadata", bundle: .module), isOn: $store.notSaveDocumentTagsAsPDFMetadata.flipped)
            Toggle(String(localized: "Require Document Tags", bundle: .module), isOn: $store.documentTagsNotRequired.flipped)
            Toggle(String(localized: "Require Document Specification", bundle: .module), isOn: $store.documentSpecificationNotRequired.flipped)
            Toggle(String(localized: "Multi-Tag Selection Delay", bundle: .module), isOn: $store.multiTagSelectionDelayEnabled)
            #if !os(macOS)
            Button {
                store.send(.onShowPermissionsTapped)
            } label: {
                Text("Show Permissions", bundle: .module)
            }
            #endif

            Button {
                store.send(.onResetAppTapped)
            } label: {
                Text("Reset App Preferences", bundle: .module)
            }
        }
        .foregroundStyle(.primary)
        .alert($store.scope(state: \.alert, action: \.alert))
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
