import ArchiverDatabase
import ArchiverModels
import ComposableArchitecture
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@testable import ArchiverFeatures

@MainActor
@Suite(.dependencies { try $0.bootstrapDatabase() })
struct DocumentDetailsTests {
    @Test
    func editWithoutSaving() async throws {
        // create tagged document
        let document = Document.mock(isTagged: true)
        let clock = TestClock()
        let store = TestStore(initialState: DocumentDetails.State(document: document)) {
            DocumentDetails()
        } withDependencies: {
            $0.continuousClock = clock
        }

        // open inspector
        await store.send(.onEditButtonTapped) {
            $0.showInspector = true
        }

        // make changes in document
        let date = Date()
        await store.send(.showDocumentInformationForm(.onSuggestedDateButtonTapped(date))) {
            $0.documentInformationForm.document.date = date
        }

        await store.send(.showDocumentInformationForm(.binding(.set(\.document.specification, "new specification")))) {
            $0.documentInformationForm.document.specification = "new specification"
        }

        await store.send(.showDocumentInformationForm(.updateTagSuggestions(["keep", "tag1"]))) {
            $0.documentInformationForm.suggestedTags = ["keep", "tag1"]
        }

        await store.send(.showDocumentInformationForm(.onTagSuggestionTapped("tag1"))) {
            $0.documentInformationForm.suggestedTags = ["keep"]
            $0.documentInformationForm.document.tags = ["tag1"]
            $0.documentInformationForm.isTagSelectionDelayActive = true
            $0.documentInformationForm.tagSelectionDelayProgress = 0.0
        }

        // Advance clock through the 2-second delay timer
        await clock.advance(by: .seconds(2))

        // Receive all progress updates
        for step in 1...20 {
            await store.receive(.showDocumentInformationForm(.updateTagSelectionDelayProgress(Double(step) / 20.0))) {
                $0.documentInformationForm.tagSelectionDelayProgress = Double(step) / 20.0
            }
        }

        await store.receive(.showDocumentInformationForm(.tagSelectionDelayCompleted)) {
            $0.documentInformationForm.isTagSelectionDelayActive = false
            $0.documentInformationForm.tagSelectionDelayProgress = 0.0
        }

        await store.receive(.showDocumentInformationForm(.startUpdatingTagSuggestions))
        await store.receive(.showDocumentInformationForm(.updateTagSuggestions([]))) {
            $0.documentInformationForm.suggestedTags = []
        }

        // close inspector without saving
        await store.send(.onEditButtonTapped) {
            $0.showInspector = false

            // reset all document properties to initial values
            $0.documentInformationForm.document = document
        }
    }

    @Test
    func runOcrSucceeds() async throws {
        let documentUrl = URL(fileURLWithPath: "/tmp/2024-01-01--scan__inbox.pdf")
        let requestedUrls = LockIsolated<[URL]>([])
        let store = TestStore(initialState: DocumentDetails.State(document: .mock(url: documentUrl, downloadStatus: 1))) {
            DocumentDetails()
        } withDependencies: {
            $0.archiveStore.reloadDocuments = { }
            $0.documentProcessor.runOcr = { url in
                requestedUrls.withValue { $0.append(url) }
                return true
            }
        }

        await store.send(.onRunOcrButtonTapped) {
            $0.isRunningOcr = true
        }
        await store.receive(.runOcrFinished(true)) {
            $0.isRunningOcr = false
        }

        #expect(requestedUrls.value == [documentUrl])
    }

    /// A tagged document is never touched by the automatic sweep, so the manual
    /// action is the only way it can ever be OCR'd.
    @Test
    func runOcrIsAvailableForTaggedDocuments() async throws {
        let documentUrl = URL(fileURLWithPath: "/tmp/2024-01-01--scan__bill.pdf")
        let requestedUrls = LockIsolated<[URL]>([])
        let store = TestStore(initialState: DocumentDetails.State(document: .mock(url: documentUrl, isTagged: true, downloadStatus: 1))) {
            DocumentDetails()
        } withDependencies: {
            $0.archiveStore.reloadDocuments = { }
            $0.documentProcessor.runOcr = { url in
                requestedUrls.withValue { $0.append(url) }
                return true
            }
        }

        await store.send(.onRunOcrButtonTapped) {
            $0.isRunningOcr = true
        }
        await store.receive(.runOcrFinished(true)) {
            $0.isRunningOcr = false
        }

        #expect(requestedUrls.value == [documentUrl])
    }

    private static func expectedDownloadFailedAlert() -> AlertState<DocumentDetails.Action.Alert> {
        AlertState {
            TextState("Download failed", bundle: .module)
        } actions: {
            ButtonState(action: .retryDownloadButtonTapped) {
                TextState("Try Again", bundle: .module)
            }
            ButtonState(role: .cancel) {
                TextState("Cancel", bundle: .module)
            }
        } message: {
            TextState("The document could not be downloaded. Please check your connection and try again.", bundle: .module)
        }
    }

    @Test
    func onRemoteDocumentAppearedFailurePresentsARetryableAlert() async throws {
        struct DownloadFailed: Error {}
        let downloadAttempts = LockIsolated<Int>(0)
        let clock = TestClock()
        let store = TestStore(initialState: DocumentDetails.State(document: .mock(downloadStatus: 0))) {
            DocumentDetails()
        } withDependencies: {
            // `.onRemoteDocumentAppeared` also starts a watchdog timer against this clock; its
            // own timeout behavior is covered by the watchdog tests below, not this one.
            $0.continuousClock = clock
            $0.archiveStore.startDownloadOf = { _ in
                downloadAttempts.withValue { $0 += 1 }
                throw DownloadFailed()
            }
        }
        store.exhaustivity = .off

        await store.send(.onRemoteDocumentAppeared)
        await store.receive(.onRemoteDocumentDownloadFailed) {
            $0.alert = Self.expectedDownloadFailedAlert()
        }
        #expect(downloadAttempts.value == 1)

        // Retry re-sends the same action, which starts the download again.
        await store.send(.alert(.presented(.retryDownloadButtonTapped))) {
            $0.alert = nil
        }
        await store.receive(.onRemoteDocumentAppeared)
        await store.receive(.onRemoteDocumentDownloadFailed) {
            $0.alert = Self.expectedDownloadFailedAlert()
        }
        #expect(downloadAttempts.value == 2)

        // `TestClock.sleep` does not observe cancellation while suspended, so both attempts'
        // cancelled watchdogs stay parked until the clock actually reaches their deadline; `Send`
        // itself checks `Task.isCancelled`, so neither delivers an action once it does.
        await clock.advance(by: DocumentDetails.downloadWatchdogInterval)
    }

    /// `startDownloadOf` only requests the download - iCloud can accept the request and then
    /// simply never report progress, which is indistinguishable from "still queued" without a
    /// timeout of its own.
    @Test
    func watchdogRestartsAStalledDownloadThenGivesUpAfterTheRetryBudgetIsExhausted() async throws {
        let clock = TestClock()
        let downloadAttempts = LockIsolated<Int>(0)
        let store = TestStore(initialState: DocumentDetails.State(document: .mock(downloadStatus: 0))) {
            DocumentDetails()
        } withDependencies: {
            $0.continuousClock = clock
            $0.archiveStore.startDownloadOf = { _ in
                downloadAttempts.withValue { $0 += 1 }
            }
        }

        await store.send(.onRemoteDocumentAppeared)
        #expect(downloadAttempts.value == 1)

        for retry in 1...DocumentDetails.maxDownloadWatchdogRetries {
            await clock.advance(by: DocumentDetails.downloadWatchdogInterval)
            await store.receive(.onRemoteDocumentDownloadWatchdogFired) {
                $0.downloadWatchdogRetryCount = retry
            }
            await store.receive(.onRemoteDocumentAppeared)
            #expect(downloadAttempts.value == retry + 1)
        }

        // One more silent interval exceeds the budget - give up instead of retrying forever.
        await clock.advance(by: DocumentDetails.downloadWatchdogInterval)
        await store.receive(.onRemoteDocumentDownloadWatchdogFired) {
            $0.downloadWatchdogRetryCount = DocumentDetails.maxDownloadWatchdogRetries + 1
        }
        await store.receive(.onRemoteDocumentDownloadFailed) {
            $0.alert = Self.expectedDownloadFailedAlert()
        }

        #expect(downloadAttempts.value == DocumentDetails.maxDownloadWatchdogRetries + 1)
    }

    /// A document that finished downloading (or was never stalled) must not be silently
    /// re-requested just because the watchdog's timer happened to fire.
    @Test
    func watchdogDoesNothingOnceTheDocumentHasDownloaded() async throws {
        let clock = TestClock()
        let downloadAttempts = LockIsolated<Int>(0)
        let store = TestStore(initialState: DocumentDetails.State(document: .mock(downloadStatus: 1))) {
            DocumentDetails()
        } withDependencies: {
            $0.continuousClock = clock
            $0.archiveStore.startDownloadOf = { _ in
                downloadAttempts.withValue { $0 += 1 }
            }
        }

        await store.send(.onRemoteDocumentAppeared)
        await clock.advance(by: DocumentDetails.downloadWatchdogInterval)
        await store.receive(.onRemoteDocumentDownloadWatchdogFired)

        #expect(downloadAttempts.value == 1)
    }

    @Test
    func runOcrFailurePresentsAlert() async throws {
        let store = TestStore(initialState: DocumentDetails.State(document: .mock(downloadStatus: 1))) {
            DocumentDetails()
        } withDependencies: {
            $0.documentProcessor.runOcr = { _ in false }
        }

        await store.send(.onRunOcrButtonTapped) {
            $0.isRunningOcr = true
        }
        await store.receive(.runOcrFinished(false)) {
            $0.isRunningOcr = false
            // #bundle does not expand in a test target; the feature's own
            // resource bundle is reachable through @testable import.
            $0.alert = AlertState {
                TextState("OCR failed", bundle: .module)
            } message: {
                TextState("The text layer of this document could not be created. Please try again.", bundle: .module)
            }
        }
    }
}
