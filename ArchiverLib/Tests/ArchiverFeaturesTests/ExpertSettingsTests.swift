import ComposableArchitecture
import Dependencies
import Foundation
import Testing

@testable import ArchiverFeatures

@MainActor
struct ExpertSettingsTests {
    /// Like "Clear Temp Folder" above it, the reset asks first; nothing is removed before the
    /// confirmation.
    @Test
    func resettingThePreferencesAsksBeforeItResets() async throws {
        let resets = LockIsolated<Int>(0)
        let store = TestStore(initialState: ExpertSettings.State()) {
            ExpertSettings()
        } withDependencies: {
            $0.fileManager.removeItemAt = { _ in }
            $0.userDefaultsManager.reset = { resets.withValue { $0 += 1 } }
        }

        await store.send(.onResetAppTapped) {
            $0.alert = AlertState {
                TextState("Reset App Preferences", bundle: .module)
            } actions: {
                ButtonState(role: .destructive, action: .confirmResetApp) {
                    TextState("Reset", bundle: .module)
                }
                ButtonState(role: .cancel) {
                    TextState("Cancel", bundle: .module)
                }
            } message: {
                TextState("This resets all preferences to their defaults. Your documents are not affected.", bundle: .module)
            }
        }
        #expect(resets.value == 0)

        await store.send(.alert(.presented(.confirmResetApp))) {
            $0.alert = AlertState {
                TextState("Reset App", bundle: .module)
            } actions: {
                ButtonState(action: .resetCompleted) {
                    TextState("OK", bundle: .module)
                }
            } message: {
                TextState("Please restart the app to complete the reset.", bundle: .module)
            }
        }
        #expect(resets.value == 1)
    }
}
