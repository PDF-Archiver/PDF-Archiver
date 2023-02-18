//
//  DocumentInformationForm.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 03.07.20.
//

import SwiftUI

struct DocumentInformationForm: View {

    @ObservedObject var viewModel: TagTabViewModel

    var body: some View {
        Form {
            HStack {
                DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                #if !os(macOS)
                Spacer()
                Button("Today" as LocalizedStringKey) {
                    viewModel.date = Date()
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Color.tertiarySystemFill)
                .cornerRadius(6)
                #endif
            }
            .labelsHidden()
            TextField("Description", text: $viewModel.specification)
                .modifier(ClearButton(text: $viewModel.specification))
            #if os(iOS)
            if #available(iOS 15.0, *) {
                documentTagsView
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(viewModel.suggestedTags) { tag in
                                        Button {
                                            viewModel.suggestedTagTapped(tag)
                                        } label: {
                                            Text(tag)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.85)
                                                .padding(EdgeInsets(top: 2.0, leading: 5.0, bottom: 2.0, trailing: 5.0))
                                                .foregroundColor(.white)
                                                .background(.paDarkRed)
                                                .cornerRadius(8.0)
                                                .padding(.horizontal, 2)
                                        }
                                    }
                                }
                            }
                            .hidden(viewModel.suggestedTags.isEmpty)
                        }
                    }
            } else {
                documentTagsView
                suggestedTagsView
            }
            #else
            documentTagsView
            suggestedTagsView
            #endif
        }
        .buttonStyle(BorderlessButtonStyle())
    }

    private var documentTagsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Document Tags")
                .font(.caption)
            TagListView(tags: $viewModel.documentTags,
                        isEditable: true,
                        isMultiLine: true,
                        tapHandler: viewModel.documentTagTapped(_:))
            TextField("Enter Tag",
                      text: $viewModel.documentTagInput,
                      onCommit: viewModel.saveTag)
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
            TagListView(tags: $viewModel.suggestedTags,
                        isEditable: false,
                        isMultiLine: true,
                        tapHandler: viewModel.suggestedTagTapped(_:))
        }
    }
}

#if DEBUG
struct DocumentInformationForm_Previews: PreviewProvider {

    static var viewModel: TagTabViewModel = {
        let model = TagTabViewModel()
        model.showLoadingView = false
        model.date = Date()
        model.documents = []
        model.documentTags = ["bill", "letter"]
        model.suggestedTags = ["tag1", "tag2", "tag3"]
        model.currentDocument = Document.create()
        return model
    }()

    struct PreviewContentView: View {
        @State var tagInput: String = "test"
        @State var tags: [String] = ["bill", "clothes"]
        @State var suggestedTags: [String] = ["tag1", "tag2", "tag3"]

        var body: some View {
            DocumentInformationForm(viewModel: viewModel)
        }
    }

    static var previews: some View {
        PreviewContentView()
            .previewLayout(.sizeThatFits)
    }
}
#endif
