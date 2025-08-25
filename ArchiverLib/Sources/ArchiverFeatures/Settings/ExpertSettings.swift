//
//  ExpertSettings.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 30.06.25.
//

import ArchiverModels
import ComposableArchitecture
import Shared
import SwiftUI

@Reducer
struct ExpertSettings {

    @ObservableState
    struct State: Equatable {

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
        Text("Expert Settings", bundle: .module)
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
