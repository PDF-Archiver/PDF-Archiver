import ComposableArchitecture
import SwiftUI

public struct RootView: View {
    @MainActor
    static let store: StoreOf<AppFeature> = {
        #if DEBUG
        if let screenshotCase = ScreenshotCase.requested {
            return Store(initialState: screenshotCase.initialState) { AppFeature() }
        }
        #endif
        return Store(initialState: AppFeature.State()) {
            AppFeature()
            #if DEBUG
//                ._printChanges()
            #endif
        }
    }()

    public init() { }

    public var body: some View {
        AppView(store: Self.store)
    }

    #if os(macOS)
    public static var settings: some View {
        SettingsMacView(store: store.scope(\.settings, action: \.settings))
    }
    #endif
}

#Preview {
  RootView()
}
