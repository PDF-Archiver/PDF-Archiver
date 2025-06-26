//
//  DocumentInformation.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 26.06.25.
//

import ComposableArchitecture
import SwiftUI
import TipKit
import Shared

@Reducer
struct DocumentInformationFeature {
    @ObservableState
    struct State {
        enum Field: Hashable {
            case date, specification, tags, save
        }
        
        var documentDate = Date()
        var suggestedDates: [Date] = []
        
        var documentDescription = ""
        
        var suggestedTags: [String] = []
        var documentTags: [String] = []
        
        var tagSearchterm: String = ""
        
        var focusedField: Field?
    }
    enum Action: BindableAction {
        case tagSearchtermSubmitted
        case tagSuggestionTapped(String)
        case tagOnDocumentTapped(String)
        case todayButtonTapped
        case saveButtonTapped
        case suggestedDateButtonTapped(Date)
        case binding(BindingAction<State>)
    }
    
    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            #warning("TODO: add this")
            switch action {
            case .binding:
                return .none
            case .tagSearchtermSubmitted:
                return .none
            case .saveButtonTapped:
                return .none
            case .suggestedDateButtonTapped(_):
                return .none
            case .tagSuggestionTapped(_):
                return .none
            case .tagOnDocumentTapped(_):
                return .none
            case .todayButtonTapped:
                return .none
            }
        }
    }
}

struct DocumentInformation: View {
    @Bindable var store: StoreOf<DocumentInformationFeature>
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState var focusedField: DocumentInformationFeature.State.Field?
    
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
                DatePicker("Date", selection: $store.documentDate, displayedComponents: .date)
                    .focused($focusedField, equals: .date)
                    .listRowSeparator(.hidden)
                HStack {
                    Spacer()

                    ForEach(store.suggestedDates, id: \.self
                    ) { date in
                        Button(date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits))) {
                            store.send(.suggestedDateButtonTapped(date))
                            
                            #warning("TODO: add this")
//                            viewModel.date = date
//                            #if canImport(UIKit)
//                            FeedbackGenerator.selectionChanged()
//                            #endif
                        }
                        .fixedSize()
                        .buttonStyle(.bordered)
                    }
                    Button("Today", systemImage: "calendar") {
                        store.send(.todayButtonTapped)
                        
                        #warning("TODO: add this")
//                        viewModel.date = Date()
//                        #if canImport(UIKit)
//                        FeedbackGenerator.selectionChanged()
//                        #endif
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                }
                .focusable(false)
            }

            Section {
                TipView(tips.currentTip as? TaggingTips.Specification)
                    .tipImageSize(TaggingTips.size)
                TextField(text: $store.documentDescription, prompt: Text("Enter specification")) {
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
                        
                        #warning("TODO: add this")
//                        viewModel.specification = viewModel.specification.slugified(withSeparator: "-")
//
//                        let filename = Document.createFilename(date: viewModel.date, specification: viewModel.specification, tags: Set(viewModel.tags))
//                        navigationModel.saveDocument(viewModel.url, to: filename, modelContext: modelContext)
//
//                        #if canImport(UIKit)
//                        FeedbackGenerator.selectionChanged()
//                        #endif
//                        focusedField = .date

//                        #if os(macOS)
//                        Task {
//                            await TaggingTips.KeyboardShortCut.documentSaved.donate()
//                        }
//                        #endif
                    }
                    .focused($focusedField, equals: .save)
                    .keyboardShortcut("s", modifiers: [.command])
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .bind($store.focusedField, to: $focusedField)
        // TODO: test this
//        .onChange(of: viewModel.tagSearchterm) { _, term in
//            viewModel.searchtermChanged(to: term, with: modelContext)
//        }
//        .onChange(of: viewModel.url, initial: true) { _, _ in
//            viewModel.analyseDocument()
//        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                ScrollView(.horizontal, showsIndicators: false) {
                    TagListView(tags: store.suggestedTags.sorted(),
                                isEditable: false,
                                isSuggestion: true,
                                isMultiLine: false,
                                tapHandler: { store.send(.tagSuggestionTapped($0)) })
                }
            }
        }
    }

    private var documentTagsSection: some View {
        Section {
            TipView(tips.currentTip as? TaggingTips.Tags)
                .tipImageSize(TaggingTips.size)
            VStack(alignment: .leading, spacing: 16) {
                if store.documentTags.isEmpty {
                    Text("No tags selected")
                        .foregroundStyle(.secondary)
                } else {
                    TagListView(tags: store.suggestedTags.sorted(),
                                isEditable: true,
                                isSuggestion: false,
                                isMultiLine: true,
                                tapHandler: { store.send(.tagOnDocumentTapped($0)) })
                    .focusable(false)
                }

                if horizontalSizeClass != .compact {
                    TagListView(tags: store.suggestedTags.sorted(),
                                isEditable: false,
                                isSuggestion: true,
                                isMultiLine: true,
                                tapHandler: { store.send(.tagSuggestionTapped($0)) })
                    .focusable(false)
                }

                TextField("Enter Tag", text: $store.tagSearchterm)
                    .onSubmit {
                        store.send(.tagSearchtermSubmitted)
                        
                        #warning("TODO: add this")
//                        let selectedTag = viewModel.tagSuggestions.sorted().first ?? viewModel.tagSearchterm.lowercased().slugified(withSeparator: "")
//                        guard !selectedTag.isEmpty else { return }
//
//                        viewModel.add(tag: selectedTag)
//                        viewModel.tagSearchterm = ""
                    }
                    .focused($focusedField, equals: .tags)
                    #if os(macOS)
                    .textFieldStyle(.squareBorder)
                    #else
                    .keyboardType(.alphabet)
                    .autocorrectionDisabled()
                    #endif
            }
        }
    }
}

#Preview {
    DocumentInformation(
        store: Store(initialState: DocumentInformationFeature.State()) {
            DocumentInformationFeature()
                ._printChanges()
        }
    )
}
