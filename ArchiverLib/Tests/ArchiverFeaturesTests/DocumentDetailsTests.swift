import ArchiverModels
import ComposableArchitecture
import Foundation
import Testing

@testable import ArchiverFeatures

@MainActor
struct DocumentDetailsTests {
    @Test
    func editWithoutSaving() async throws {
        // create tagged document
        let sharedDocument = Shared(value: Document.mock(isTagged: true))
        let clock = TestClock()
        let store = TestStore(initialState: DocumentDetails.State(document: sharedDocument)) {
            DocumentDetails()
        } withDependencies: {
            $0.archiveStore.getTagSuggestionsSimilarTo = { _ in [] }
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
            $0.documentInformationForm.document = sharedDocument.wrappedValue
        }
    }

    @Test
    func runOcrSucceeds() async throws {
        let documentUrl = URL(fileURLWithPath: "/tmp/2024-01-01--scan__inbox.pdf")
        let requestedUrls = LockIsolated<[URL]>([])
        let store = TestStore(initialState: DocumentDetails.State(document: Shared(value: .mock(url: documentUrl, downloadStatus: 1)))) {
            DocumentDetails()
        } withDependencies: {
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
        let store = TestStore(initialState: DocumentDetails.State(document: Shared(value: .mock(url: documentUrl, isTagged: true, downloadStatus: 1)))) {
            DocumentDetails()
        } withDependencies: {
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

    @Test
    func runOcrFailurePresentsAlert() async throws {
        let store = TestStore(initialState: DocumentDetails.State(document: Shared(value: .mock(downloadStatus: 1)))) {
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
