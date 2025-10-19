//
//  DocumentInformationForm.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 26.06.25.
//

import ArchiverModels
import ComposableArchitecture
import ContentExtractorStore
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

        @SharedReader(.notSaveDocumentTagsAsPDFMetadata)
        var notSaveDocumentTagsAsPDFMetadata: Bool

        @SharedReader(.documentTagsNotRequired)
        var documentTagsNotRequired: Bool

        @SharedReader(.documentSpecificationNotRequired)
        var documentSpecificationNotRequired: Bool

        @SharedReader(.appleIntelligenceEnabled)
        var appleIntelligenceEnabled: Bool

        /// Initial version of the document (e.g. in the global state)
        ///
        /// This will be needed for comparison if changes were made.
        let initialDocument: Document

        /// Information of the `Document`
        ///
        /// We explicitly stick to a copy (not `@Shared`) of `Document` because in this case we do not want to manipulate the "global state" in the documents array.
        /// Changes will be done on a copy and only be propagated when `save` was called.
        var document: Document

        var isLoading = false

        var suggestedDates: [Date] = []
        var suggestedTags: [String] = []
        var tagSearchterm: String = ""

        var focusedField: Field?

        init(document: Document, suggestedTags: [String] = []) {
            self.document = document
            self.initialDocument = document

            self.suggestedTags = suggestedTags
        }
    }
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case finishedLoading
        case onTask
        case onTagOnDocumentTapped(String)
        case onTagSearchtermSubmitted
        case onTagSuggestionTapped(String)
        case onTagSuggestionsUpdated([String])
        case onTodayButtonTapped
        case onSaveButtonTapped
        case onSuggestedDateButtonTapped(Date)
        case updateDocumentData(DocumentParsingResult)
        case updateTagSuggestions

        enum Delegate: Equatable {
            case saveDocument(Document, shouldUpdatePdfMetadata: Bool)
        }
    }

    @Dependency(\.archiveStore) var archiveStore
    @Dependency(\.textAnalyser) var textAnalyser
    @Dependency(\.contentExtractorStore) var contentExtractorStore
    @Dependency(\.calendar) var calendar
    @Dependency(\.notificationCenter) var notificationCenter

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

            case .finishedLoading:
                state.isLoading = false
                return .none

            case .onTagSearchtermSubmitted:
                let selectedTag = state.suggestedTags.first ?? state.tagSearchterm.lowercased().slugified(withSeparator: "")
                guard !selectedTag.isEmpty else { return .none }

                _ = state.document.tags.insert(selectedTag)
                state.tagSearchterm = ""

                return .send(.updateTagSuggestions)

            case .onSaveButtonTapped:
                let nothingChanged = state.initialDocument.date == state.document.date && state.initialDocument.specification == state.document.specification && state.initialDocument.tags == state.document.tags
                guard !nothingChanged else {
                    return .none
                }

                // check tags
                if !state.documentTagsNotRequired && state.document.tags.isEmpty {
                    return .run { _ in
                        await notificationCenter.createAndPost(.init(title: LocalizedStringResource("Missing tags", bundle: .module),
                                                                     message: LocalizedStringResource("Please add at least one tag to your document or change your advanced settings.", bundle: .module),
                                                                     primaryButtonTitle: LocalizedStringResource("OK", bundle: .module)))
                    }
                }

                // check specification
                state.document.specification = state.document.specification.slugified(withSeparator: "-")
                if !state.documentSpecificationNotRequired && state.document.specification.isEmpty {
                    return .run { _ in
                        await notificationCenter.createAndPost(.init(title: LocalizedStringResource("No specification", bundle: .module),
                                                                     message: LocalizedStringResource("Please add the document specification or change your advanced settings.", bundle: .module),
                                                                     primaryButtonTitle: LocalizedStringResource("OK", bundle: .module)))
                    }
                }

                return .send(.delegate(.saveDocument(state.document, shouldUpdatePdfMetadata: !state.notSaveDocumentTagsAsPDFMetadata)))

            case .onSuggestedDateButtonTapped(let date):
                state.document.date = date
                return .none

            case .onTask:
                state.isLoading = true
                return .run { [documentUrl = state.document.url, isTagged = state.document.isTagged, appleIntelligenceEnabled = state.appleIntelligenceEnabled] send in

                    if isTagged {
                        await send(.updateTagSuggestions)
                    } else {
                        let result = await parseDocumentData(url: documentUrl, appleIntelligenceEnabled: appleIntelligenceEnabled)
                        await send(.updateDocumentData(result))
                    }

                    await send(.finishedLoading)
                }

            case .onTagSuggestionsUpdated(let suggestedTags):
                state.suggestedTags = suggestedTags
                return .none

            case .onTagSuggestionTapped(var tag):
                tag = tag.lowercased()
                _ = state.document.tags.insert(tag)
                state.suggestedTags.removeAll { $0 == tag }

                // remove current tagSearchteam - this will also trigger the new analyses of the tags
                state.tagSearchterm = ""

                return .send(.updateTagSuggestions)

            case .onTagOnDocumentTapped(var tag):
                tag = tag.lowercased()
                _ = state.document.tags.remove(tag)
                return .send(.updateTagSuggestions)

            case .onTodayButtonTapped:
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
                return .run { [tagSearchterm = state.tagSearchterm, documentTags = state.document.tags] send in
                    let tags: [String]
                    if tagSearchterm.isEmpty {
                        guard !documentTags.isEmpty else { return }
                        tags = await archiveStore.getTagSuggestionsSimilarTo(documentTags)
                    } else {
                        tags = await archiveStore.getTagSuggestionsFor(tagSearchterm.lowercased())
                    }

                    await send(.onTagSuggestionsUpdated(tags))
                }
                // we do not need multiple fetches of tag suggestions - so we cancelInFlight suggestions
                .cancellable(id: CancelID.updateTagSuggestions, cancelInFlight: true)
            }
        }
    }

    struct DocumentParsingResult: Equatable {
        let date: Date?
        let specification: String?
        let tags: Set<String>?
        let dateSuggestions: [Date]?
        let tagSuggestions: [String]?
    }
    private func parseDocumentData(url: URL, appleIntelligenceEnabled: Bool) async -> DocumentParsingResult {

        // analyse document content and fill suggestions
        let parserOutput = await archiveStore.parseFilename(url.lastPathComponent)
        var tagNames = Set(parserOutput.tagNames ?? [])

        var foundDate = parserOutput.date
        var foundSpecification = parserOutput.specification
        var dateSuggestions: [Date]?
        var tagSuggestions: [String]?

        if let text = await textAnalyser.getTextFrom(url) {
            // Try Apple Intelligence first if enabled and available
            if appleIntelligenceEnabled,
               await contentExtractorStore.isAvailable() == .available,
               let content = await contentExtractorStore.getDocumentInformation(text) {
                foundSpecification = content.specification
                tagSuggestions = Array(content.tags).sorted()
            } else {
                // Fall back to traditional text analysis
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
                DatePicker(String(localized: "Date", bundle: .module), selection: $store.document.date, displayedComponents: .date)
                    .focused($focusedField, equals: .date)
                    .listRowSeparator(.hidden)
                    .sensoryFeedback(.selection, trigger: store.document.date)
                HStack {
                    Spacer()

                    ForEach(store.suggestedDates, id: \.self
                    ) { date in
                        Button(date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits))) {
                            store.send(.onSuggestedDateButtonTapped(date))
                        }
                        .fixedSize()
                        .buttonStyle(.bordered)
                    }
                    Button(String(localized: "Today", bundle: .module), systemImage: "calendar") {
                        store.send(.onTodayButtonTapped)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                }
                .focusable(false)
            }

            Section {
                TipView(tips.currentTip as? TaggingTips.Specification)
                    .tipImageSize(TaggingTips.size)
                TextField(text: $store.document.specification, prompt: Text("Enter specification", bundle: .module), axis: .vertical) {
                    Text("Specification", bundle: .module)
                }
                .lineLimit(1...5)
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
                    Button(String(localized: "Save", bundle: .module)) {
                        store.send(.onSaveButtonTapped)
                        #if os(macOS)
                        Task {
                            await TaggingTips.KeyboardShortCut.documentSaved.donate()
                        }
                        #endif
                    }
                    .buttonStyle(.bordered)
                    .focused($focusedField, equals: .save)
                    .keyboardShortcut("s", modifiers: [.command])
                    Spacer()
                }
            }
            .overlay(alignment: .trailing) {
                if store.isLoading {
                    ProgressView()
                }
            }
        }
        .formStyle(.grouped)
        .bind($store.focusedField, to: $focusedField)
        .task {
            await store.send(.onTask).finish()
        }
    }

    private var documentTagsSection: some View {
        Section {
            TipView(tips.currentTip as? TaggingTips.Tags)
                .tipImageSize(TaggingTips.size)
            VStack(alignment: .leading, spacing: 16) {
                if store.document.tags.isEmpty {
                    Text("No tags selected", bundle: .module)
                        .foregroundStyle(.secondary)
                } else {
                    TagListView(tags: store.document.tags.sorted(),
                                isEditable: true,
                                isSuggestion: false,
                                isMultiLine: true,
                                tapHandler: { store.send(.onTagOnDocumentTapped($0)) })
                    .focusable(false)
                }

                TagListView(tags: store.suggestedTags,
                            isEditable: false,
                            isSuggestion: true,
                            isMultiLine: true,
                            tapHandler: { store.send(.onTagSuggestionTapped($0)) })
                .focusable(false)

                TextField(String(localized: "Enter Tag", bundle: .module), text: $store.tagSearchterm)
                    .onSubmit {
                        store.send(.onTagSearchtermSubmitted)
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
