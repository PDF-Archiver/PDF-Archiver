//
//  AppFeature.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 05.07.25.
//

import DomainModels
import ComposableArchitecture
import SwiftUI

@Reducer
struct AppFeature {
    
    // STACK: here we could model the state as an enum to create a navigation stack path
//    @Reducer
//    struct Path {
//        enum State {
//            case archiveList(ArchiveList.State)
//        }
//        enum Action {
//            case archiveList(ArchiveList.Action)
//        }
//        
//        var body: some ReducerOf<Self> {
//            Scope(state: \.archiveList, action: \.archiveList) {
//                ArchiveList()
//            }
//        }
//    }
    
    @ObservableState
    struct State: Equatable {
        enum Tab: Hashable {
            case search
            case inbox
            case statistics
            case settings
            case sectionTags(String)
            case sectionYears(Int)
        }
        
        var selectedTab = Tab.search
        var archiveList = ArchiveList.State()
    }

    enum Action: BindableAction {
        // STACK: add path actions
//        case path(StackActionOf<Path>)
        case archiveList(ArchiveList.Action)
        case binding(BindingAction<State>)
    }
    
    var body: some ReducerOf<Self> {
        // frist, run the ArchiveList reducer ...
        Scope(state: \.archiveList, action: \.archiveList) {
            ArchiveList()
        }

        // ... second, run AppFeature reducer, if we need to interact (from an AppFeature domain point of view) with it
        Reduce { state, action in
            switch action {
            case .archiveList:
                return .none
            case .binding(_):
                return .none
            }
        }
        // STACK: integrate reducers
//        .forEach(\.path, action: \.path) {
//            Path()
//        }
    }

}

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
//        ArchiveListView(store: store.scope(state: \.archiveList, action: \.archiveList))
        // STACK: model the navigation stack here
//        NavigationStackStore(self.store.scope(state: \.path, action: \.path)) {
//            <#code#>
//        } destination: { store in
//            <#code#>
//        }
        
        TabView(selection: $store.selectedTab) {
            Tab(value: AppFeature.State.Tab.search, role: .search) {
                Text("TODO: Search archive")
            }
            Tab("Inbox", systemImage: "tray", value: AppFeature.State.Tab.inbox) {
                Text("TODO: untagged documents")
            }
            Tab("Statistics", systemImage: "chart.bar.xaxis", value: AppFeature.State.Tab.statistics) {
                Text("TODO: Some charts")
            }
            
            #if !os(macOS)
            Tab("Settings", systemImage: "gear", value: AppFeature.State.Tab.settings) {
                Text("TODO: Settings")
            }
            #endif
            
            TabSection("Tags") {
                Tab("tag1", systemImage: "tag", value: AppFeature.State.Tab.sectionTags("tag1")) {
                    Text("TODO: add tag in search")
                }
                Tab("tag2", systemImage: "tag", value: AppFeature.State.Tab.sectionTags("tag2")) {
                    Text("TODO: add tag in search")
                }
            }
            .defaultVisibility(.hidden, for: .tabBar)

            TabSection("Years") {
                Tab("2025", systemImage: "calendar", value: AppFeature.State.Tab.sectionYears(2025)) {
                    Text("TODO: add year in search")
                }
            }
            .defaultVisibility(.hidden, for: .tabBar)
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    AppView(store: Store(initialState: AppFeature.State()) {
        AppFeature()
        }
    )
}
