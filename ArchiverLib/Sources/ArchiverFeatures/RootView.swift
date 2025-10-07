import ComposableArchitecture
import SwiftUI

public struct RootView: View {
    static let store = Store(initialState: AppFeature.State()) {
        AppFeature()
        #if DEBUG
//            ._printChanges()
        #endif
    }

    public init() { }

    public var body: some View {
        AppView(store: Self.store)
    }
    
    #if os(macOS)
    public static var settings: some View {
        SettingsMacView(store: store.scope(state: \.settings, action: \.settings))
    }
    #endif
}

#Preview {
  RootView()
}
