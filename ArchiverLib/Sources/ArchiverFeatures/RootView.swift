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
        #if DEBUG
            // Screenshot cases that open a document have to do it after the first render.
            .task {
                guard let screenshotCase = ScreenshotCase.requested else { return }
                try? await Task.sleep(for: .milliseconds(500))
                screenshotCase.activate(Self.store)
            }
        #endif
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
