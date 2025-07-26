import ComposableArchitecture
import ArchiverModels
import Foundation
import Testing

@testable import ArchiverFeatures

@MainActor
struct DocumentInformationFormTests {
    @Test
    func selectDate() async throws {
        let store = TestStore(initialState: DocumentInformationForm.State(document: .mock())) {
            DocumentInformationForm()
        }
        
        let selectedDate = try Date("2025-07-26T15:00:0Z", strategy: .iso8601)
        await store.send(.onSuggestedDateButtonTapped(selectedDate)) {
            $0.document.date = selectedDate
        }
    }
    
    @Test
    func selectSuggestedTag() async throws {
        let store = TestStore(initialState: DocumentInformationForm.State(document: .mock())) {
            DocumentInformationForm()
        } withDependencies: {
            $0.archiveStore.getTagSuggestionsSimilarTo = { _ in [] }
        }
        
        await store.send(.onTagSuggestionsUpdated(["tag1", "tag2"])) {
            $0.suggestedTags = ["tag1", "tag2"]
        }
        
        await store.send(.onTagSuggestionTapped("tag1")) {
            $0.suggestedTags = ["tag2"]
            $0.document.tags = ["tag1"]
        }
        
        await store.receive(.updateTagSuggestions)
        await store.receive(.onTagSuggestionsUpdated([])) {
            $0.suggestedTags = []
        }
    }
    
    @Test
    func submitTagSearchteam() async throws {
        let store = TestStore(initialState: DocumentInformationForm.State(document: .mock(), suggestedTags: ["first", "second"])) {
            DocumentInformationForm()
        } withDependencies: {
            $0.archiveStore.getTagSuggestionsSimilarTo = { _ in ["fitsfirst"] }
        }
        
        await store.send(.onTagSearchtermSubmitted) {
            $0.document.tags = ["first"]
        }
        
        await store.receive(.updateTagSuggestions)
        await store.receive(.onTagSuggestionsUpdated(["fitsfirst"])) {
            $0.suggestedTags = ["fitsfirst"]
        }
    }

    
    @Test
    func updateDocumentData() async throws {
        let store = TestStore(initialState: DocumentInformationForm.State(document: .mock())) {
            DocumentInformationForm()
        }
        
        let date = Date()
        let parsingResult = DocumentInformationForm.DocumentParsingResult(
            date: date,
            specification: "blue-hoodie",
            tags: ["bill", "clothes"],
            dateSuggestions: nil,
            tagSuggestions: ["hoodie"])
        await store.send(.updateDocumentData(parsingResult)) {
            $0.document.date = date
            $0.document.specification = "blue-hoodie"
            $0.document.tags = ["bill", "clothes"]
            $0.suggestedTags = ["hoodie"]
        }
    }
    
    @Test
    func save() async throws {
        let document: Document = .mock()
        let store = TestStore(initialState: DocumentInformationForm.State(document: document)) {
            DocumentInformationForm()
        }
        
        await store.send(.onSaveButtonTapped)
        await store.receive(.delegate(.saveDocument(document)))
    }
}
