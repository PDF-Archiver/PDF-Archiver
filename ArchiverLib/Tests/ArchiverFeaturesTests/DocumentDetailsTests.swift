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

        await store.send(.showDocumentInformationForm(.onTagSuggestionTapped("tag1"))) {
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
        await store.receive(.showDocumentInformationForm(.updateTagSuggestions([])))

        // close inspector without saving
        await store.send(.onEditButtonTapped) {
            $0.showInspector = false

            // reset all document properties to initial values
            $0.documentInformationForm.document = sharedDocument.wrappedValue
        }
    }
}
