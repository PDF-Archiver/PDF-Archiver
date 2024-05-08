//
//  DocumentInformation.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 03.04.24.
//

import SwiftData
import SwiftUI
import OSLog
import PDFKit

@Observable
class DocumentInformationViewModel {
    let url: URL
    var date = Date()
    var specification = ""
    private(set) var tags: [String] = []
    
    var tagSearchterm = ""
    var tagSuggestions: [String] = []
    var dateSuggestions: [Date] = []
    
    init(url: URL ) {
        self.url = url
    }
    
    func add(tag name: String) {
        var uniqueTags = Set(tags)
        uniqueTags.insert(name.lowercased())
        tags = uniqueTags.sorted()
        
        tagSuggestions = tagSuggestions.filter { $0 != name }
        
        // remove current tagSearchteam - this will also trigger the new analyses of the tags
        tagSearchterm = ""
    }
    
    func remove(tag name: String) {
        tags = tags.filter { $0 != name.lowercased() }
        
        var newTags = Set(tagSuggestions)
        newTags.insert(name)
        tagSuggestions = newTags.sorted()
    }
    
    func analyseDocument() async {
        // analyse document content and fill suggestions
        let parserOutput = Document.parseFilename(url.lastPathComponent)
        
        var foundDate = parserOutput.date
        var foundTags = (parserOutput.tagNames ?? []).isEmpty ? nil : parserOutput.tagNames
        let foundSpecification = parserOutput.specification
        
        if foundDate == nil || foundTags == nil,
           let pdfDocument = PDFDocument(url: url) {
            // get the pdf content of first 3 pages
            var text = ""
            for index in 0 ..< min(pdfDocument.pageCount, 3) {
                guard let page = pdfDocument.page(at: index),
                      let pageContent = page.string else { return }
                
                text += pageContent
            }
            
            if foundDate == nil {
                foundDate = DateParser.parse(text)?.date
            }
            if foundTags == nil {
                foundTags = TagStore.shared.getTags(from: text).sorted()
            }
        }
        
        date = foundDate ?? Date()
        tags = foundTags ?? []
        specification = foundSpecification ?? ""
    }
    
    func save() {
        specification = specification.slugified(withSeparator: "-")
        
        let filename = Document.createFilename(date: date, specification: specification, tags: Set(tags))
        Task {
            do {
                try await NewArchiveStore.shared.archiveFile(from: url, to: filename)
            } catch {
                // TODO: handle error
                Logger.archiveStore.errorAndAssert("Failed to save document \(error)")
            }
        }
    }
    
    /// get new new tag suggestions
    func searchtermChanged(to newSearchterm: String, with modelContext: ModelContext) {   
        do {
            let trimmedSearchTeam = newSearchterm.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if trimmedSearchTeam.isEmpty {
                // no searchterm -> suggest tags that were used in other documents
                guard let tag = tags.first else {
                    tagSuggestions = []
                    return
                }
                let predicate = #Predicate<DBDocument> {
                    // the tag might exist in the specification - filter afterwards again
                    $0.filename.contains(tag)
                }
                var descriptor = FetchDescriptor<DBDocument>(predicate: predicate)
                descriptor.fetchLimit = 1000
                let documents = try modelContext.fetch(descriptor)

                let filteredDocuments = documents.filter { document in
                    Set(document.tags).isSuperset(of: tags)
                }
                
                let filteredTags = Set(filteredDocuments.flatMap(\.tags)).subtracting(tags)
                tagSuggestions = Array(filteredTags.sorted().prefix(10))
            } else {
                
                
                let predicate = #Predicate<DBDocument> {
                    // the tag might exist in the specification - filter afterwards again
                    $0.filename.contains(trimmedSearchTeam)
                }
                
                var descriptor = FetchDescriptor<DBDocument>(predicate: predicate)
                descriptor.fetchLimit = 1000
                let documents = try modelContext.fetch(descriptor)
                let filteredTags = Set(documents.flatMap(\.tags)).filter { $0.contains(trimmedSearchTeam) }

                tagSuggestions = Set(filteredTags).subtracting(tags).sorted()
            }
        } catch {
            // TODO: handle error
            Logger.archiveStore.errorAndAssert("Error found \(error)")
        }
    }
}

struct DocumentInformation: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var information: DocumentInformationViewModel

    var body: some View {
        Form {
            Section {
                DatePicker("Date", selection: $information.date, displayedComponents: .date)
                HStack {
                    Spacer()

                    ForEach(information.dateSuggestions, id: \.self
                    ) { date in
                        Button("Today" as LocalizedStringKey) {
                            information.date = date
                            FeedbackGenerator.selectionChanged()
                        }
                    }
                    Button("Today" as LocalizedStringKey) {
                        information.date = Date()
                        FeedbackGenerator.selectionChanged()
                    }
                    
                }
                .focusable(false)
            }

            Section {
                TextField(text: $information.specification, prompt: Text("Enter specification")) {
                    Text("Specification")
                }
                .textFieldStyle(.squareBorder)
            }
            
            Section {
                if information.tags.isEmpty {
                    Text("No tags selected")
                        .foregroundStyle(.secondary)
                } else {
                    TagListView(tags: information.tags,
                                isEditable: true,
                                isSuggestion: false,
                                isMultiLine: true,
                                tapHandler: information.remove(tag:))
                }
                
                TagListView(tags: information.tagSuggestions,
                            isEditable: false,
                            isSuggestion: true,
                            isMultiLine: true,
                            tapHandler: information.add(tag:))
                
                TextField("Enter Tag",
                          text: $information.tagSearchterm,
                          onCommit: {
                    // TODO: validate tagSearchterm (lowercased etc.)
                    let selectedTag = information.tagSuggestions.first ?? information.tagSearchterm
                    guard !selectedTag.isEmpty else { return }
                    
                    information.add(tag: selectedTag)
                    DispatchQueue.main.async {
                        information.tagSearchterm = ""
                    }
                })
                .textFieldStyle(.squareBorder)
#if os(iOS)
                .keyboardType(.alphabet)
#endif
            }
            .onChange(of: information.tagSearchterm) { _, term in
                information.searchtermChanged(to: term, with: modelContext)
            }
            
            Section {
                HStack {
                    Spacer()
                    Button("Save" as LocalizedStringKey) {
                        information.save()
                        FeedbackGenerator.selectionChanged()
                    }
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .task {
            await information.analyseDocument()
        }
    }
    
    private var documentTagsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Document Tags")
                .font(.caption)
            TagListView(tags: information.tags,
                        isEditable: true,
                        isSuggestion: false,
                        isMultiLine: true,
                        tapHandler: { print($0) })
            TextField(text: .constant("test"),
                      onCommit: {})
            #if os(iOS)
            .keyboardType(.alphabet)
            #endif
            .disableAutocorrection(true)
            .frame(maxHeight: 22)
            .padding(EdgeInsets(top: 4.0, leading: 0.0, bottom: 4.0, trailing: 0.0))
        }
    }

    private var suggestedTagsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Suggested Tags")
                .font(.caption)
//            TagListView(tags: viewModel.suggestedTags,
//                        isEditable: false,
//                        isMultiLine: true,
//                        tapHandler: viewModel.suggestedTagTapped(_:))
        }
    }
}

#Preview("Document Information", traits: .fixedLayout(width: 400, height: 600)) {
    let information = DocumentInformationViewModel(url: .documentsDirectory)
    information.specification = "test-specification"
    information.add(tag: "tag1")
    information.add(tag: "tag2")
    information.tagSuggestions = ["suggestion1", "suggestion2"]
    return DocumentInformation(information: information)
        .modelContainer(previewContainer)
}
