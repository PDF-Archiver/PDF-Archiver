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

        @Shared(.notSaveDocumentTagsAsPDFMetadata)
        var notSaveDocumentTagsAsPDFMetadata: Bool

        @Shared(.documentTagsNotRequired)
        var documentTagsNotRequired: Bool

        @Shared(.documentSpecificationNotRequired)
        var documentSpecificationNotRequired: Bool
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        #if !os(macOS)
        case onShowPermissionsTapped
        #endif
        case onResetAppTapped
    }

    @Dependency(\.openURL) var openURL
    @Dependency(\.fileManager) var fileManager
    @Dependency(\.userDefaultsManager) var userDefaultsManager
    @Dependency(\.notificationCenter) var notificationCenter

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { _, action in
            switch action {
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

                #warning("TODO: notification only pops up for a short amount of time the first time")
                notificationCenter.createAndPost(.init(title: "Reset App",
                                                   message: "Please restart the app to complete the reset.",
                                                   primaryButtonTitle: "OK"))

                return .none
            }
        }
    }
}

struct ExpertSettingsView: View {
    @Bindable var store: StoreOf<ExpertSettings>

    var body: some View {
        Form {
            Toggle(String(localized: "Save Tags in PDF Metadata", bundle: .module), isOn: $store.notSaveDocumentTagsAsPDFMetadata.flipped)
            Toggle(String(localized: "Require Document Tags", bundle: .module), isOn: $store.documentTagsNotRequired.flipped)
            Toggle(String(localized: "Require Document Specification", bundle: .module), isOn: $store.documentSpecificationNotRequired.flipped)
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
