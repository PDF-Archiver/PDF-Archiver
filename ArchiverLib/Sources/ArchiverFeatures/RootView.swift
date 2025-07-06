import ComposableArchitecture
import SwiftUI

public struct RootView: View {
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
            ._printChanges()
    }

    public init() {}
    
    public var body: some View {
        AppView(store: store)
    }
}

#Preview {
  RootView()
}
