//
//  DocumentInformationForm.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 26.06.25.
//

import ArchiverModels
import ArchiverStore
import ComposableArchitecture
import ContentExtractorStore
import Shared
import SwiftUI
import TipKit

@Reducer
struct DocumentInformationForm {

    enum CancelID {
        case startUpdatingAllSuggestionsWithAI
        case startUpdatingTagSuggestions
        case tagSelectionDelayTimer
    }

    @ObservableState
    struct State: Equatable {
        enum Field: Hashable, CaseIterable {
            case date, specification, tags, save

            /// Wraps in both directions - this is what keeps Tab from leaving the inspector.
            func next(forward: Bool) -> Field {
                let all = Self.allCases
                let index = all.firstIndex(of: self) ?? 0
                let offset = forward ? 1 : all.count - 1
                return all[(index + offset) % all.count]
            }
        }

        @SharedReader(.notSaveDocumentTagsAsPDFMetadata)
        var notSaveDocumentTagsAsPDFMetadata: Bool

        @SharedReader(.documentTagsNotRequired)
        var documentTagsNotRequired: Bool

        @SharedReader(.documentSpecificationNotRequired)
        var documentSpecificationNotRequired: Bool

        @SharedReader(.appleIntelligenceEnabled)
        var appleIntelligenceEnabled: Bool

        @SharedReader(.appleIntelligenceCustomPrompt)
        var customPrompt: String?

        @SharedReader(.multiTagSelectionDelayEnabled)
        var multiTagSelectionDelayEnabled: Bool

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

        var tagSelectionDelayProgress: Double = 0.0
        var isTagSelectionDelayActive = false

        init(document: Document, suggestedTags: [String] = []) {
            self.document = document
            self.initialDocument = document

            self.suggestedTags = suggestedTags
        }
    }
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case onSaveButtonTapped
        case onSuggestedDateButtonTapped(Date)
        case onTabKeyPressed(forward: Bool)
        case onTagOnDocumentTapped(String)
        case onTagSearchtermSubmitted
        case onTagSuggestionTapped(String)
        case onTask
        case onTodayButtonTapped
        case startUpdatingAllSuggestionsWithAI(URL)
        case startUpdatingTagSuggestions
        case updateDocumentData(DocumentParsingResult)
        case updateTagSuggestions([String])
        case updateTagSelectionDelayProgress(Double)
        case tagSelectionDelayCompleted

        enum Delegate: Equatable {
            case saveDocument(Document, shouldUpdatePdfMetadata: Bool)
        }
    }

    @Dependency(\.archiveStore) var archiveStore
    @Dependency(\.textAnalyser) var textAnalyser
    @Dependency(\.contentExtractorStore) var contentExtractorStore
    @Dependency(\.calendar) var calendar
    @Dependency(\.notificationCenter) var notificationCenter
    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        BindingReducer()
            .onChange(of: \.tagSearchterm) { _, _ in
                .send(.startUpdatingTagSuggestions)
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .delegate:
                return .none

            case .onSaveButtonTapped:
                let nothingChanged = state.initialDocument.date == state.document.date && state.initialDocument.specification == state.document.specification && state.initialDocument.tags == state.document.tags
                if nothingChanged, state.document.isTagged {
                    state.focusedField = .date
                    return .none
                }

                // check tags
                if !state.documentTagsNotRequired, state.document.tags.isEmpty {
                    return .run { _ in
                        await notificationCenter.createAndPost(.init(title: LocalizedStringResource("Missing tags", bundle: #bundle),
                                                                     message: LocalizedStringResource("Please add at least one tag to your document or change your advanced settings.", bundle: #bundle),
                                                                     primaryButtonTitle: LocalizedStringResource("OK", bundle: #bundle)))
                    }
                }

                // check specification
                state.document.specification = state.document.specification.slugified(withSeparator: "-")
                if !state.documentSpecificationNotRequired, state.document.specification.isEmpty {
                    return .run { _ in
                        await notificationCenter.createAndPost(.init(title: LocalizedStringResource("No specification", bundle: #bundle),
                                                                     message: LocalizedStringResource("Please add the document specification or change your advanced settings.", bundle: #bundle),
                                                                     primaryButtonTitle: LocalizedStringResource("OK", bundle: #bundle)))
                    }
                }

                state.focusedField = .date
                return .send(.delegate(.saveDocument(state.document, shouldUpdatePdfMetadata: !state.notSaveDocumentTagsAsPDFMetadata)))

            case .onSuggestedDateButtonTapped(let date):
                state.document.date = date
                return .none

            case .onTabKeyPressed(let forward):
                state.focusedField = state.focusedField?.next(forward: forward) ?? .date
                return .none

            case .onTagOnDocumentTapped(var tag):
                tag = tag.lowercased()
                _ = state.document.tags.remove(tag)
                return .send(.startUpdatingTagSuggestions)

            case .onTagSearchtermSubmitted:
                let selectedTag = state.suggestedTags.first ?? state.tagSearchterm.lowercased().slugified(withSeparator: "")
                guard !selectedTag.isEmpty else { return .none }

                _ = state.document.tags.insert(selectedTag)
                state.tagSearchterm = ""

                return .send(.startUpdatingTagSuggestions)

            case .onTagSuggestionTapped(var tag):
                tag = tag.lowercased()
                _ = state.document.tags.insert(tag)
                state.suggestedTags.removeAll { $0.lowercased() == tag }

                // remove current tagSearchteam
                state.tagSearchterm = ""

                // The delay only buys time to pick more of the shown suggestions - with none left there is nothing to wait for
                guard state.multiTagSelectionDelayEnabled,
                      !state.suggestedTags.isEmpty else {
                    state.isTagSelectionDelayActive = false
                    state.tagSelectionDelayProgress = 0.0

                    return .run { send in
                        await send(.startUpdatingTagSuggestions)
                    }
                    .cancellable(id: CancelID.tagSelectionDelayTimer, cancelInFlight: true)
                }

                state.isTagSelectionDelayActive = true
                state.tagSelectionDelayProgress = 0.0

                return .run { send in
                    let delayDuration: TimeInterval = 2
                    let steps = 20
                    let stepDuration = delayDuration / Double(steps)

                    for step in 1...steps {
                        try await clock.sleep(for: .seconds(stepDuration))
                        await send(.updateTagSelectionDelayProgress(Double(step) / Double(steps)))
                    }

                    await send(.tagSelectionDelayCompleted)
                }
                .cancellable(id: CancelID.tagSelectionDelayTimer, cancelInFlight: true)

            case .onTask:
                state.isLoading = true
                state.focusedField = .date
                return .run { [documentUrl = state.document.url, isTagged = state.document.isTagged] send in
                    if isTagged {
                        await send(.startUpdatingTagSuggestions)
                    } else {
                        await send(.startUpdatingAllSuggestionsWithAI(documentUrl))
                    }
                }

            case .onTodayButtonTapped:
                state.document.date = Date()
                return .none

            case .startUpdatingAllSuggestionsWithAI(let documentUrl):
                return .run { [appleIntelligenceEnabled = state.appleIntelligenceEnabled, customPrompt = state.customPrompt, documentId = state.document.id] send in
                    let result = await startUpdatingAllSuggestionsWithAI(url: documentUrl, appleIntelligenceEnabled: appleIntelligenceEnabled, customPrompt: customPrompt, documentId: documentId)
                    await send(.updateDocumentData(result))
                }
                // we try to abort the foundation model response after content generation
                .cancellable(id: CancelID.startUpdatingAllSuggestionsWithAI, cancelInFlight: true)

            case .startUpdatingTagSuggestions:
                return .run { [tagSearchterm = state.tagSearchterm, documentTags = state.document.tags] send in
                    let tags: [String]
                    if tagSearchterm.isEmpty {
                        guard !documentTags.isEmpty else { return }
                        tags = await archiveStore.getTagSuggestionsSimilarTo(documentTags)
                    } else {
                        tags = await archiveStore.getTagSuggestionsFor(tagSearchterm.lowercased())
                    }

                    await send(.updateTagSuggestions(tags))
                }
                // we do not need multiple fetches of tag suggestions - so we cancelInFlight suggestions
                .cancellable(id: CancelID.startUpdatingTagSuggestions, cancelInFlight: true)

            case .updateDocumentData(let result):
                state.isLoading = false

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
                    let documentTags = Set(state.document.tags.map { $0.lowercased() })
                    state.suggestedTags = tagSuggestions.filter { !documentTags.contains($0.lowercased()) }
                }
                return .none

            case .updateTagSuggestions(let suggestedTags):
                state.isLoading = false
                state.suggestedTags = suggestedTags.sorted()
                return .none

            case .updateTagSelectionDelayProgress(let progress):
                state.tagSelectionDelayProgress = progress
                return .none

            case .tagSelectionDelayCompleted:
                state.isTagSelectionDelayActive = false
                state.tagSelectionDelayProgress = 0.0
                return .send(.startUpdatingTagSuggestions)
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

    private func startUpdatingAllSuggestionsWithAI(url: URL, appleIntelligenceEnabled: Bool, customPrompt: String?, documentId: Document.ID) async -> DocumentParsingResult {

        // analyse document content and fill suggestions
        let parserOutput = await archiveStore.parseFilename(url.lastPathComponent)
        var tagNames = Set(parserOutput.tagNames ?? [])

        var foundDate = parserOutput.date
        var foundSpecification = parserOutput.specification
        var dateSuggestions: [Date]?
        var tagSuggestions: [String]?

        if let text = await textAnalyser.getTextFrom(url) {

            // STEP 1 - try to find date
            var results = await textAnalyser.parseDateFrom(text)
            if let foundDate {
                results = results.filter { resultDate in
                    !Calendar.current.isDate(resultDate, inSameDayAs: foundDate)
                }
            }

            let newResults = results
                .dropFirst(foundDate == nil ? 1 : 0)    // skip first because it is set to foundDate
                .filter { !calendar.isDate($0, inSameDayAs: Date()) }   // skip found "today" dates, because a today button will always be shown
                .prefix(3)
            dateSuggestions = Array(newResults)

            if foundDate == nil {
                foundDate = results.first
            }

            // STEP 2 - try to find specification and tags
            // Try Apple Intelligence first if enabled and available
            if appleIntelligenceEnabled,
               await contentExtractorStore.isAvailable() == .available,
               let content = await contentExtractorStore.getDocumentInformation(.init(currentDocuments: (try? await archiveStore.getDocuments()) ?? [],
                                                                                      text: text,
                                                                                      customPrompt: customPrompt,
                                                                                      documentId: documentId)) {
                foundSpecification = content.specification
                tagSuggestions = Array(content.tags).sorted()
            } else {
                // Fall back to traditional text analysis

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

/// Gives one control ownership of Tab, so focus cycles through the form instead of escaping into the surrounding focus loop.
struct TabCycleModifier: ViewModifier {
    let store: StoreOf<DocumentInformationForm>

    /// Tab, plus macOS's translation of Shift-Tab (`NSBackTabCharacter`, U+0019) - there is no `KeyEquivalent.backTab`.
    static let interceptedKeys: Set<KeyEquivalent> = [.tab, KeyEquivalent("\u{19}")]

    func body(content: Content) -> some View {
        content.onKeyPress(keys: Self.interceptedKeys, phases: [.down, .repeat]) { keyPress in
            // Consume repeats too, so a held key can't leak into the system's own focus movement;
            // only `.down` advances, which keeps the cycle at one step per physical press.
            guard keyPress.phase == .down else { return .handled }
            store.send(.onTabKeyPressed(forward: !keyPress.modifiers.contains(.shift)))
            return .handled
        }
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
                    .focusable(false)
                DatePicker(String(localized: "Date", bundle: #bundle), selection: $store.document.date, displayedComponents: .date)
                    .focused($focusedField, equals: .date)
                    .modifier(TabCycleModifier(store: store))
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
                        .focusable(false)
                        // The visible short digits read as an ambiguous number to VoiceOver; spell out the date and its purpose.
                        .accessibilityLabel(Text("Suggested date: \(date.formatted(date: .long, time: .omitted))", bundle: #bundle))
                        .accessibilityHint(Text("Sets the document date to this value", bundle: #bundle))
                    }
                    Button(String(localized: "Today", bundle: #bundle), systemImage: "calendar") {
                        store.send(.onTodayButtonTapped)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .focusable(false)
                }
            }

            Section {
                TipView(tips.currentTip as? TaggingTips.Specification)
                    .tipImageSize(TaggingTips.size)
                    .focusable(false)
                TextField(text: $store.document.specification, prompt: Text("Enter specification", bundle: #bundle), axis: .vertical) {
                    Text("Specification", bundle: #bundle)
                }
                .lineLimit(1...5)
                .focused($focusedField, equals: .specification)
                .modifier(TabCycleModifier(store: store))
            }

            documentTagsSection

            Section {
                #if os(macOS)
                TipView(tips.currentTip as? TaggingTips.KeyboardShortCut)
                    .tipImageSize(TaggingTips.size)
                    .focusable(false)
                #endif
                HStack {
                    Spacer()
                    Button(String(localized: "Save", bundle: #bundle)) {
                        store.send(.onSaveButtonTapped)
                        #if os(macOS)
                        Task {
                            await TaggingTips.KeyboardShortCut.documentSaved.donate()
                        }
                        #endif
                    }
                    .buttonStyle(.bordered)
                    .focused($focusedField, equals: .save)
                    .modifier(TabCycleModifier(store: store))
#if os(iOS)
                    .keyboardShortcut("s", modifiers: [.command])
#endif
                    Spacer()
                }
            }
            .overlay(alignment: .trailing) {
                if store.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .bind($store.focusedField, to: $focusedField)
        .task(id: store.document.id) {
            await store.send(.onTask).finish()
        }
    }

    private var documentTagsSection: some View {
        Section {
            TipView(tips.currentTip as? TaggingTips.Tags)
                .tipImageSize(TaggingTips.size)
            VStack(alignment: .leading, spacing: 16) {
                if store.document.tags.isEmpty {
                    Text("No tags selected", bundle: #bundle)
                        .foregroundStyle(.tertiary)
                        .padding(EdgeInsets(top: 2.0, leading: 5.0, bottom: 2.0, trailing: 5.0))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8.0)
                                .stroke(Color.tertiaryLabelAsset, lineWidth: 1)
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    TagListView(tags: store.document.tags.sorted(),
                                isEditable: true,
                                isSuggestion: false,
                                isMultiLine: true,
                                tapHandler: { store.send(.onTagOnDocumentTapped($0)) })
                }

                HStack(alignment: .top) {
                    TagListView(tags: store.suggestedTags,
                                isEditable: false,
                                isSuggestion: true,
                                isMultiLine: true,
                                tapHandler: { store.send(.onTagSuggestionTapped($0)) })

                    if store.isTagSelectionDelayActive {
                        CircularProgressView(progress: store.tagSelectionDelayProgress)
                            .frame(width: 20, height: 20)
                    }
                }

                TextField(text: $store.tagSearchterm, prompt: Text("Enter Tag", bundle: #bundle)) {
                    Text("Tag", bundle: #bundle)
                }
                .onSubmit {
                    store.send(.onTagSearchtermSubmitted)
                }
                .focused($focusedField, equals: .tags)
                .modifier(TabCycleModifier(store: store))
                #if os(iOS)
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
