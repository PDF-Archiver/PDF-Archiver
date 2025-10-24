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
        let store = TestStore(initialState: DocumentDetails.State(document: sharedDocument)) {
            DocumentDetails()
        } withDependencies: {
            $0.archiveStore.getTagSuggestionsSimilarTo = { _ in [] }
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
        }
        await store.receive(.showDocumentInformationForm(.updateTagSuggestions))
        await store.receive(.showDocumentInformationForm(.onTagSuggestionsUpdated([])))

        // close inspector without saving
        await store.send(.onEditButtonTapped) {
            $0.showInspector = false

            // reset all document properties to initial values
            $0.documentInformationForm.document = sharedDocument.wrappedValue
        }
    }
}
