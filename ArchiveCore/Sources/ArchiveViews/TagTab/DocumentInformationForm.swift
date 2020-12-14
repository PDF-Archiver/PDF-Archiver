//
//  DocumentInformationForm.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 03.07.20.
//

import SwiftUI
import SwiftUIX

struct DocumentInformationForm: View {

    @Binding var date: Date
    @Binding var specification: String
    @Binding var tags: [String]

    @Binding var tagInput: String
    @Binding var suggestedTags: [String]

    var body: some View {
        Form {
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .labelsHidden()
            Spacer()
            TextField("Description", text: $specification)
                .modifier(ClearButton(text: $specification))
            Spacer()
            documentTagsView
            Spacer()
            suggestedTagsView
        }
        .buttonStyle(BorderlessButtonStyle())
        .padding(8)
    }

    private func documentTagTapped(_ tag: String) {
        tags.removeAll { $0 == tag }
        insertAndSort($suggestedTags, tag: tag)
    }

    private func saveCurrentTag() {
        let tag = tagInput
        tagInput = ""
        insertAndSort($tags, tag: tag)
    }

    private func suggestedTagTapped(_ tag: String) {
        suggestedTags.removeAll { $0 == tag }
        insertAndSort($tags, tag: tag)
    }

    private func insertAndSort(_ tags: Binding<[String]>, tag: String) {
        var uniqueTags = Set(tags.wrappedValue)
        uniqueTags.insert(tag)
        tags.wrappedValue = uniqueTags.sorted()
    }

    private var documentTagsView: some View {
        VStack(alignment: .leading) {
            Text("Document Tags")
                .font(.caption)
            TagListView(tags: $tags,
                        isEditable: true,
                        isMultiLine: true,
                        tapHandler: documentTagTapped(_:))
                .font(.caption)
            TextField("Enter Tag",
                      text: $tagInput,
                      onCommit: saveCurrentTag)
                .frame(maxHeight: 22)
                .padding(EdgeInsets(top: 4.0, leading: 0.0, bottom: 4.0, trailing: 0.0))
        }
    }

    private var suggestedTagsView: some View {
        VStack(alignment: .leading) {
            Text("Suggested Tags")
                .font(.caption)
            TagListView(tags: $suggestedTags,
                        isEditable: false,
                        isMultiLine: true,
                        tapHandler: suggestedTagTapped(_:))
                .font(.body)
        }
    }
}

struct DocumentInformationForm_Previews: PreviewProvider {

    struct PreviewContentView: View {
        @State var tagInput: String = "test"
        @State var tags: [String] = ["bill", "clothes"]
        @State var suggestedTags: [String] = ["tag1", "tag2", "tag3"]

        var body: some View {
            DocumentInformationForm(date: .constant(Date()),
                                    specification: .constant("Blue Pullover"),
                                    tags: $tags,
                                    tagInput: $tagInput,
                                    suggestedTags: $suggestedTags)
                }
        }

    static var previews: some View {
        PreviewContentView()
            .previewLayout(.sizeThatFits)
    }
}
