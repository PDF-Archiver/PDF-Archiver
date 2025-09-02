//
//  ExpertSettings.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 30.06.25.
//

import ComposableArchitecture
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
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { _, action in
            switch action {
            case .binding:
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
            #warning("TODO: add this")
//            if let showPermissions = showPermissions {
//                DetailRowView(name: "Show Permissions", action: showPermissions)
//            }
//            DetailRowView(name: "Reset App Preferences", action: resetApp)
        }
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
