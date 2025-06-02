//
//  DocumentInformation.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 03.04.24.
//

import OSLog
import PDFKit
import SwiftData
import SwiftUI
import TipKit

struct DocumentInformation: View {
    @Environment(NavigationModel.self) private var navigationModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @FocusState private var focusedField: DocumentInformation.ViewModel.Field?
    @Binding var viewModel: DocumentInformation.ViewModel
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
                DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                    .focused($focusedField, equals: .date)
                    .listRowSeparator(.hidden)
                HStack {
                    Spacer()

                    ForEach(viewModel.dateSuggestions, id: \.self
                    ) { date in
                        Button(date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits))) {
                            viewModel.date = date
                            #if canImport(UIKit)
                            FeedbackGenerator.selectionChanged()
                            #endif
                        }
                        .fixedSize()
                        .buttonStyle(.bordered)
                    }
                    Button("Today", systemImage: "calendar") {
                        viewModel.date = Date()
                        #if canImport(UIKit)
                        FeedbackGenerator.selectionChanged()
                        #endif
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                }
                .focusable(false)
            }

            Section {
                TipView(tips.currentTip as? TaggingTips.Specification)
                    .tipImageSize(TaggingTips.size)
                TextField(text: $viewModel.specification, prompt: Text("Enter specification")) {
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
                        viewModel.specification = viewModel.specification.slugified(withSeparator: "-")

                        let filename = Document.createFilename(date: viewModel.date, specification: viewModel.specification, tags: Set(viewModel.tags))
                        navigationModel.saveDocument(viewModel.url, to: filename, modelContext: modelContext)

                        #if canImport(UIKit)
                        FeedbackGenerator.selectionChanged()
                        #endif
                        focusedField = .date

                        #if os(macOS)
                        Task {
                            await TaggingTips.KeyboardShortCut.documentSaved.donate()
                        }
                        #endif
                    }
                    .focused($focusedField, equals: .save)
                    .keyboardShortcut("s", modifiers: [.command])
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: viewModel.tagSearchterm) { _, term in
            viewModel.searchtermChanged(to: term, with: modelContext)
        }
        .onChange(of: viewModel.url, initial: true) { _, _ in
            viewModel.analyseDocument()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                ScrollView(.horizontal, showsIndicators: false) {
                    TagListView(tags: viewModel.tagSuggestions.sorted(),
                                isEditable: false,
                                isSuggestion: true,
                                isMultiLine: false,
                                tapHandler: viewModel.add(tag:))
                }
            }
        }
    }

    private var documentTagsSection: some View {
        Section {
            TipView(tips.currentTip as? TaggingTips.Tags)
                .tipImageSize(TaggingTips.size)
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.tags.isEmpty {
                    Text("No tags selected")
                        .foregroundStyle(.secondary)
                } else {
                    TagListView(tags: viewModel.tags.sorted(),
                                isEditable: true,
                                isSuggestion: false,
                                isMultiLine: true,
                                tapHandler: viewModel.remove(tag:))
                    .focusable(false)
                }

                if horizontalSizeClass != .compact {
                    TagListView(tags: viewModel.tagSuggestions.sorted(),
                                isEditable: false,
                                isSuggestion: true,
                                isMultiLine: true,
                                tapHandler: viewModel.add(tag:))
                    .focusable(false)
                }

                TextField("Enter Tag", text: $viewModel.tagSearchterm)
                    .onSubmit {
                        let selectedTag = viewModel.tagSuggestions.sorted().first ?? viewModel.tagSearchterm.lowercased().slugified(withSeparator: "")
                        guard !selectedTag.isEmpty else { return }

                        viewModel.add(tag: selectedTag)
                        viewModel.tagSearchterm = ""
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

extension DocumentInformation {
    @Observable
    final class ViewModel {
        enum Field: Hashable {
            case date, specification, tags, save
        }

        let url: URL
        var date = Date()
        var specification = ""
        private(set) var tags: Set<String> = []

        var tagSearchterm = ""
        private(set) var tagSuggestions: Set<String> = []
        private(set) var dateSuggestions: [Date] = []

        init(url: URL) {
            self.url = url
        }

        func add(tag name: String) {
            tags.insert(name.lowercased())
            tagSuggestions.remove(name.lowercased())

            // remove current tagSearchteam - this will also trigger the new analyses of the tags
            tagSearchterm = ""
        }

        func remove(tag name: String) {
            tags.remove(name.lowercased())
            tagSuggestions.insert(name.lowercased())
        }

        func analyseDocument() {
            Logger.taggingView.debug("Analyzing document \(self.url.lastPathComponent)")

            // analyse document content and fill suggestions
            let parserOutput = Document.parseFilename(url.lastPathComponent)
            var tagNames = Set(parserOutput.tagNames ?? [])

            var foundDate = parserOutput.date
            let foundSpecification = parserOutput.specification

            if let pdfDocument = PDFDocument(url: url) {
                // get the pdf content of first 3 pages
                var text = ""
                for index in 0 ..< min(pdfDocument.pageCount, 3) {
                    guard let page = pdfDocument.page(at: index),
                          let pageContent = page.string else { return }

                    text += pageContent
                }

                if text.isEmpty {
                    Logger.taggingView.warning("Could not extract text from PDF")
                }

                var results = DateParser.parse(text)
                if let foundDate {
                    results = results.filter { resultDate in
                        !Calendar.current.isDate(resultDate, inSameDayAs: foundDate)
                    }
                }

                let newResults = results
                    .dropFirst(foundDate == nil ? 1 : 0)    // skip first because it is set to foundDate
                    .filter { !Calendar.current.isDate($0, inSameDayAs: Date()) }   // skip found "today" dates, because a today button will always be shown
//                    .sorted().reversed().prefix(3)  // get the most recent 3 dates
//                    .sorted()
                    .prefix(3)
                dateSuggestions = Array(newResults)

                if foundDate == nil {
                    foundDate = results.first
                }
                if tagNames.isEmpty {
                    tagSuggestions = TagParser.parse(text)
                }
            }

            // add tags from Finder tags
            tagNames.formUnion(url.getFileTags())

            date = foundDate ?? Date()
            tags = tagNames
            specification = foundSpecification ?? ""
        }

        /// get new new tag suggestions
        func searchtermChanged(to newSearchterm: String, with modelContext: ModelContext) {
            do {
                let trimmedSearchTeam = newSearchterm.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if trimmedSearchTeam.isEmpty {
                    // no searchterm -> suggest tags that were used in other documents
                    guard let tag = tags.sorted().first else {
                        tagSuggestions = []
                        return
                    }
                    let predicate = #Predicate<Document> {
                        // the tag might exist in the specification - filter afterwards again
                        $0.filename.contains(tag)
                    }
                    var descriptor = FetchDescriptor<Document>(predicate: predicate)
                    descriptor.fetchLimit = 1000
                    let documents = try modelContext.fetch(descriptor)

                    let filteredDocuments = documents.filter { document in
                        Set(document.tags).isSuperset(of: tags)
                    }

                    let filteredTags = Set(filteredDocuments.flatMap(\.tags)).subtracting(tags)
                    tagSuggestions = Set(filteredTags.sorted().prefix(10))
                } else {

                    let predicate = #Predicate<Document> {
                        // the tag might exist in the specification - filter afterwards again
                        $0.filename.contains(trimmedSearchTeam)
                    }

                    var descriptor = FetchDescriptor<Document>(predicate: predicate)
                    descriptor.fetchLimit = 1000
                    let documents = try modelContext.fetch(descriptor)
                    let filteredTags = Set(documents.flatMap(\.tags)).filter { $0.starts(with: trimmedSearchTeam) }

                    tagSuggestions = Set(Set(filteredTags).subtracting(tags).sorted().prefix(10))
                }
            } catch {
                Logger.archiveStore.error("Searchterm changed \(error)")
                NotificationCenter.default.postAlert(error)
            }
        }
    }
}

#if DEBUG
#Preview("Document Information", traits: .fixedLayout(width: 400, height: 600)) {
    let information = DocumentInformation.ViewModel(url: .documentsDirectory)
    information.specification = "test-specification"
    information.add(tag: "tag1")
    information.add(tag: "tag2")
    return DocumentInformation(viewModel: .constant(information))
        .modelContainer(previewContainer())
}
#endif
