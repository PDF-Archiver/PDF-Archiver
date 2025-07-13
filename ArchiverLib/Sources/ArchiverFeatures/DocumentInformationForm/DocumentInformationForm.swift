//
//  DocumentInformationForm.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 26.06.25.
//

import ArchiverModels
import ComposableArchitecture
import Shared
import SwiftUI
import TipKit

@Reducer
struct DocumentInformationForm {

    enum CancelID { case updateTagSuggestions }

    @ObservableState
    struct State: Equatable {
        enum Field: Hashable {
            case date, specification, tags, save
        }

        /// Initial version of the document (e.g. in the global state)
        ///
        /// This will be needed for comparison if changes were made.
        let initialDocument: Document

        /// Information of the `Document`
        ///
        /// We explicitly stick to a copy (not `@Shared`) of `Document` because in this case we do not want to manipulate the "global state" in the documents array.
        /// Changes will be done on a copy and only be propagated when `save` was called.
        var document: Document

        var suggestedDates: [Date] = []
        var suggestedTags: [String] = []
        var tagSearchterm: String = ""

        var focusedField: Field?

        init(document: Document) {
            self.document = document
            self.initialDocument = document
        }
    }
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case onTask
        case tagSearchtermSubmitted
        case tagSuggestionTapped(String)
        case tagSuggestionsUpdated([String])
        case tagOnDocumentTapped(String)
        case todayButtonTapped
        case saveButtonTapped
        case suggestedDateButtonTapped(Date)
        case updateDocumentData(DocumentParsingResult)
        case updateTagSuggestions

        enum Delegate {
            case saveDocument(Document)
        }
    }

    @Dependency(\.archiveStore) var archiveStore
    @Dependency(\.textAnalyser) var textAnalyser
    @Dependency(\.calendar) var calendar

    var body: some ReducerOf<Self> {
        BindingReducer()
            .onChange(of: \.tagSearchterm) { _, _ in
                Reduce { _, _ in
                    return .send(.updateTagSuggestions)
                }
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .delegate:
                return .none

            case .tagSearchtermSubmitted:
                let selectedTag = state.suggestedTags.first ?? state.tagSearchterm.lowercased().slugified(withSeparator: "")
                guard !selectedTag.isEmpty else { return .none }

                _ = state.document.tags.insert(selectedTag)
                state.suggestedTags.removeAll()
                state.tagSearchterm = ""

                return .send(.updateTagSuggestions)

            case .saveButtonTapped:
                state.document.specification = state.document.specification.slugified(withSeparator: "-")
                return .send(.delegate(.saveDocument(state.document)))

            case .suggestedDateButtonTapped(let date):
                state.document.date = date
                return .none

            case .onTask:
                // skip analysis for tagged documents
                guard !state.document.isTagged else { return .none }
                return .run { [documentUrl = state.document.url] send in
                    await send(.updateTagSuggestions)

                    let result = await parseDocumentData(url: documentUrl)
                    await send(.updateDocumentData(result))
                }

            case .tagSuggestionsUpdated(let suggestedTags):
                state.suggestedTags = suggestedTags
                return .none

            case .tagSuggestionTapped(var tag):
                tag = tag.lowercased()
                _ = state.document.tags.insert(tag)
                state.suggestedTags.removeAll { $0 == tag }

                // remove current tagSearchteam - this will also trigger the new analyses of the tags
                state.tagSearchterm = ""

                return .send(.updateTagSuggestions)

            case .tagOnDocumentTapped(var tag):
                tag = tag.lowercased()
                _ = state.document.tags.remove(tag)
                return .send(.updateTagSuggestions)

            case .todayButtonTapped:
                state.document.date = Date()
                return .none

            case .updateDocumentData(let result):
                if let date = result.date {
                    state.document.date = date
                }
                if let specification = result.specification {
                    state.document.specification = specification
                }
                if let tags = result.tags {
                    state.document.tags = tags
                }
                if let dateSuggestions = result.dateSuggestions {
                    state.suggestedDates = dateSuggestions
                }
                if let tagSuggestions = result.tagSuggestions {
                    state.suggestedTags = tagSuggestions
                }
                return .none

            case .updateTagSuggestions:
#warning("also run this on appear")
                return .run { [tagSearchterm = state.tagSearchterm, documentTags = state.document.tags] send in
                    let tags: [String]
                    if tagSearchterm.isEmpty {
                        tags = await archiveStore.getTagSuggestionsSimilarTo(documentTags)
                    } else {
                        tags = await archiveStore.getTagSuggestionsFor(tagSearchterm.lowercased())
                    }

                    await send(.tagSuggestionsUpdated(tags))
                }
                // we do not need multiple fetches of tag suggestions - so we cancelInFlight suggestions
                .cancellable(id: CancelID.updateTagSuggestions, cancelInFlight: true)
            }
        }
    }

    struct DocumentParsingResult {
        let date: Date?
        let specification: String?
        let tags: Set<String>?
        let dateSuggestions: [Date]?
        let tagSuggestions: [String]?
    }
    private func parseDocumentData(url: URL) async -> DocumentParsingResult {

        // analyse document content and fill suggestions
        let parserOutput = await archiveStore.parseFilename(url.lastPathComponent)
        var tagNames = Set(parserOutput.tagNames ?? [])

        var foundDate = parserOutput.date
        let foundSpecification = parserOutput.specification
        var dateSuggestions: [Date]?
        var tagSuggestions: [String]?

        if let text = await textAnalyser.getTextFrom(url) {

            var results = await textAnalyser.parseDateFrom(text)
            if let foundDate {
                results = results.filter { resultDate in
                    !Calendar.current.isDate(resultDate, inSameDayAs: foundDate)
                }
            }

            let newResults = results
                .dropFirst(foundDate == nil ? 1 : 0)    // skip first because it is set to foundDate
                .filter { !calendar.isDate($0, inSameDayAs: Date()) }   // skip found "today" dates, because a today button will always be shown
            //                    .sorted().reversed().prefix(3)  // get the most recent 3 dates
            //                    .sorted()
                .prefix(3)
            dateSuggestions = Array(newResults)

            if foundDate == nil {
                foundDate = results.first
            }
            if tagNames.isEmpty {
                tagSuggestions = await textAnalyser.parseTagsFrom(text).sorted()
            }
        }

        // add tags from Finder tags
        tagNames.formUnion((try? await textAnalyser.getFileTagsFrom(url)) ?? [])

        let date = foundDate ?? Date()
        let tags = tagNames
        let specification = foundSpecification ?? ""

        return DocumentParsingResult(date: date, specification: specification, tags: tags, dateSuggestions: dateSuggestions, tagSuggestions: tagSuggestions)
    }
}

struct DocumentInformationFormView: View {
    @Bindable var store: StoreOf<DocumentInformationForm>
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState var focusedField: DocumentInformationForm.State.Field?

    @State private var tips = TipGroup(.ordered) {
        TaggingTips.Date()
        TaggingTips.Specification()
        TaggingTips.Tags()
        #if os(macOS)
        TaggingTips.KeyboardShortCut()
        #endif
    }

    var body: some View {
        Form {
            Section {
                TipView(tips.currentTip as? TaggingTips.Date)
                    .tipImageSize(TaggingTips.size)
                DatePicker("Date", selection: $store.document.date, displayedComponents: .date)
                    .focused($focusedField, equals: .date)
                    .listRowSeparator(.hidden)
                    .sensoryFeedback(.selection, trigger: store.document.date)
                HStack {
                    Spacer()

                    ForEach(store.suggestedDates, id: \.self
                    ) { date in
                        Button(date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits))) {
                            store.send(.suggestedDateButtonTapped(date))
                        }
                        .fixedSize()
                        .buttonStyle(.bordered)
                    }
                    Button("Today", systemImage: "calendar") {
                        store.send(.todayButtonTapped)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                }
                .focusable(false)
            }

            Section {
                TipView(tips.currentTip as? TaggingTips.Specification)
                    .tipImageSize(TaggingTips.size)
                TextField(text: $store.document.specification, prompt: Text("Enter specification")) {
                    Text("Specification")
                }
                .focused($focusedField, equals: .specification)
                #if os(macOS)
                .textFieldStyle(.squareBorder)
                #endif
            }

            documentTagsSection

            Section {
                #if os(macOS)
                TipView(tips.currentTip as? TaggingTips.KeyboardShortCut)
                    .tipImageSize(TaggingTips.size)
                #endif
                HStack {
                    Spacer()
                    Button("Save") {
                        store.send(.saveButtonTapped)
                        #if os(macOS)
                        Task {
                            await TaggingTips.KeyboardShortCut.documentSaved.donate()
                        }
                        #endif
                    }
                    .buttonStyle(.bordered)
                    .focused($focusedField, equals: .save)
                    .disabled(store.initialDocument == store.document)
                    .keyboardShortcut("s", modifiers: [.command])
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .bind($store.focusedField, to: $focusedField)
        #warning("Add this")
//        .onChange(of: viewModel.url, initial: true) { _, _ in
//            viewModel.analyseDocument()
//        }
    }

    private var documentTagsSection: some View {
        Section {
            TipView(tips.currentTip as? TaggingTips.Tags)
                .tipImageSize(TaggingTips.size)
            VStack(alignment: .leading, spacing: 16) {
                if store.document.tags.isEmpty {
                    Text("No tags selected")
                        .foregroundStyle(.secondary)
                } else {
                    TagListView(tags: store.document.tags.sorted(),
                                isEditable: true,
                                isSuggestion: false,
                                isMultiLine: true,
                                tapHandler: { store.send(.tagOnDocumentTapped($0)) })
                    .focusable(false)
                }

                TagListView(tags: store.suggestedTags,
                            isEditable: false,
                            isSuggestion: true,
                            isMultiLine: true,
                            tapHandler: { store.send(.tagSuggestionTapped($0)) })
                .focusable(false)

                TextField("Enter Tag", text: $store.tagSearchterm)
                    .onSubmit {
                        store.send(.tagSearchtermSubmitted)
                    }
                    .focused($focusedField, equals: .tags)
                    #if os(macOS)
                    .textFieldStyle(.squareBorder)
                    #else
                    .keyboardType(.alphabet)
                    .autocorrectionDisabled()
                    #endif
            }
            .sensoryFeedback(.selection, trigger: store.document.tags)
        }
    }
}

#Preview {
    DocumentInformationFormView(
        store: Store(initialState: DocumentInformationForm.State(document: .mock())) {
            DocumentInformationForm()
                ._printChanges()
        }
    )
}
