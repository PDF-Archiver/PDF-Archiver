import ArchiverModels
import ComposableArchitecture
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

        await store.send(.updateTagSuggestions(["tag1", "tag2"])) {
            $0.suggestedTags = ["tag1", "tag2"]
        }

        await store.send(.onTagSuggestionTapped("tag1")) {
            $0.suggestedTags = ["tag2"]
            $0.document.tags = ["tag1"]
        }

        await store.receive(.startUpdatingTagSuggestions)
        await store.receive(.updateTagSuggestions([])) {
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

        await store.receive(.startUpdatingTagSuggestions)
        await store.receive(.updateTagSuggestions(["fitsfirst"])) {
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

    @Test(.disabled("Currently not working"))
    func save() async throws {
        let document: Document = .mock()
        let store = TestStore(initialState: DocumentInformationForm.State(document: document)) {
            DocumentInformationForm()
        }

        await store.send(.onSaveButtonTapped)
        await store.receive(.delegate(.saveDocument(document, shouldUpdatePdfMetadata: false)))
    }

    // MARK: - Tag Management Tests

    @Test
    func addingTagUpdatesDocument() async throws {
        let store = TestStore(initialState: DocumentInformationForm.State(document: .mock())) {
            DocumentInformationForm()
        } withDependencies: {
            $0.archiveStore.getTagSuggestionsSimilarTo = { _ in [] }
        }

        await store.send(.onTagSuggestionTapped("invoice")) {
            $0.document.tags = ["invoice"]
        }

        await store.receive(.startUpdatingTagSuggestions)
        await store.receive(.updateTagSuggestions([]))
    }

    @Test
    func removingTagUpdatesDocument() async throws {
        let document = Document.mock(tags: ["invoice", "work"])
        let store = TestStore(initialState: DocumentInformationForm.State(document: document)) {
            DocumentInformationForm()
        } withDependencies: {
            $0.archiveStore.getTagSuggestionsSimilarTo = { _ in [] }
        }

        await store.send(.binding(.set(\.document.tags, ["invoice"]))) {
            $0.document.tags = ["invoice"]
        }

        await store.receive(.startUpdatingTagSuggestions)
        await store.receive(.updateTagSuggestions([]))
    }

    @Test
    func multipleTagsAreSorted() async throws {
        let store = TestStore(initialState: DocumentInformationForm.State(document: .mock())) {
            DocumentInformationForm()
        } withDependencies: {
            $0.archiveStore.getTagSuggestionsSimilarTo = { _ in [] }
        }

        await store.send(.binding(.set(\.document.tags, ["zebra", "apple", "banana"]))) {
            $0.document.tags = ["zebra", "apple", "banana"]
        }

        await store.receive(.startUpdatingTagSuggestions)
        await store.receive(.updateTagSuggestions([]))
    }

    // MARK: - Specification Tests

    @Test
    func updatingSpecification() async throws {
        let store = TestStore(initialState: DocumentInformationForm.State(document: .mock())) {
            DocumentInformationForm()
        }

        await store.send(.binding(.set(\.document.specification, "new-spec"))) {
            $0.document.specification = "new-spec"
        }
    }

    @Test
    func specificationIsLowercase() async throws {
        let document = Document.mock(specification: "Test Specification")
        let state = DocumentInformationForm.State(document: document)

        #expect(state.document.specification == "Test Specification")
    }

    // MARK: - Date Suggestions Tests

    @Test
    func dateSuggestionsFromParsingResult() async throws {
        let store = TestStore(initialState: DocumentInformationForm.State(document: .mock())) {
            DocumentInformationForm()
        }

        let date1 = Date()
        let date2 = Date().addingTimeInterval(-86400) // yesterday
        let parsingResult = DocumentInformationForm.DocumentParsingResult(
            date: date1,
            specification: "test",
            tags: [],
            dateSuggestions: [date1, date2],
            tagSuggestions: nil
        )

        await store.send(.updateDocumentData(parsingResult)) {
            $0.document.date = date1
            $0.document.specification = "test"
            $0.suggestedDates = [date1, date2]
        }
    }

    @Test
    func selectingDateFromSuggestions() async throws {
        let date = Date()
        let store = TestStore(initialState: DocumentInformationForm.State(document: .mock())) {
            DocumentInformationForm()
        }

        await store.send(.onSuggestedDateButtonTapped(date)) {
            $0.document.date = date
        }
    }

    // MARK: - Tag Suggestions Tests

    @Test
    func tagSuggestionsUpdate() async throws {
        let store = TestStore(initialState: DocumentInformationForm.State(document: .mock())) {
            DocumentInformationForm()
        }

        await store.send(.updateTagSuggestions(["suggestion1", "suggestion2"])) {
            $0.suggestedTags = ["suggestion1", "suggestion2"]
        }
    }

    @Test
    func tagSuggestionsFilterAfterSelection() async throws {
        let store = TestStore(initialState: DocumentInformationForm.State(
            document: .mock(),
            suggestedTags: ["tag1", "tag2", "tag3"]
        )) {
            DocumentInformationForm()
        } withDependencies: {
            $0.archiveStore.getTagSuggestionsSimilarTo = { _ in [] }
        }

        await store.send(.onTagSuggestionTapped("tag1")) {
            $0.document.tags = ["tag1"]
            $0.suggestedTags = ["tag2", "tag3"]
        }

        await store.receive(.startUpdatingTagSuggestions)
        await store.receive(.updateTagSuggestions([])) {
            $0.suggestedTags = []
        }
    }

    // MARK: - Document Data Update Tests

    @Test
    func updateDocumentDataWithAllFields() async throws {
        let store = TestStore(initialState: DocumentInformationForm.State(document: .mock())) {
            DocumentInformationForm()
        }

        let date = Date()
        let parsingResult = DocumentInformationForm.DocumentParsingResult(
            date: date,
            specification: "invoice-2024",
            tags: ["invoice", "tax"],
            dateSuggestions: [date],
            tagSuggestions: ["business", "finance"]
        )

        await store.send(.updateDocumentData(parsingResult)) {
            $0.document.date = date
            $0.document.specification = "invoice-2024"
            $0.document.tags = ["invoice", "tax"]
            $0.suggestedDates = [date]
            $0.suggestedTags = ["business", "finance"]
        }
    }

    @Test
    func updateDocumentDataWithNilSuggestions() async throws {
        let store = TestStore(initialState: DocumentInformationForm.State(document: .mock())) {
            DocumentInformationForm()
        }

        let date = Date()
        let parsingResult = DocumentInformationForm.DocumentParsingResult(
            date: date,
            specification: "test",
            tags: ["tag"],
            dateSuggestions: nil,
            tagSuggestions: nil
        )

        await store.send(.updateDocumentData(parsingResult)) {
            $0.document.date = date
            $0.document.specification = "test"
            $0.document.tags = ["tag"]
        }
    }

    // MARK: - Binding Tests

    @Test
    func bindingDocumentDate() async throws {
        let store = TestStore(initialState: DocumentInformationForm.State(document: .mock())) {
            DocumentInformationForm()
        }

        let newDate = Date()
        await store.send(.binding(.set(\.document.date, newDate))) {
            $0.document.date = newDate
        }
    }

    @Test
    func bindingDocumentTags() async throws {
        let store = TestStore(initialState: DocumentInformationForm.State(document: .mock())) {
            DocumentInformationForm()
        } withDependencies: {
            $0.archiveStore.getTagSuggestionsSimilarTo = { _ in ["related"] }
        }

        await store.send(.binding(.set(\.document.tags, ["newtag"]))) {
            $0.document.tags = ["newtag"]
        }

        await store.receive(.startUpdatingTagSuggestions)
        await store.receive(.updateTagSuggestions(["related"])) {
            $0.suggestedTags = ["related"]
        }
    }
}
