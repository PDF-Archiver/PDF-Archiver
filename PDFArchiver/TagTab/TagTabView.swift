//
//  TagTabView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 02.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import KeyboardObserving
import SwiftUI

struct TagTabView: View {
    @ObservedObject var viewModel: TagTabViewModel

    var body: some View {
        // TODO: profile laggy first initialization
        NavigationView {
            if viewModel.currentDocument != nil {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16.0) {
                        pdfView
                        datePicker
                        TextField("Description", text: $viewModel.specification)
                        documentTags
                        suggestedTags
                    }
                }
                .keyboardObserving()
                .padding(EdgeInsets(top: 0.0, leading: 8.0, bottom: 0.0, trailing: 8.0))
                .navigationBarTitle(Text("Document"), displayMode: .inline)
                .navigationBarItems(leading: deleteNavBarView, trailing: saveNavBarView)
            } else {
                PlaceholderView(name: "No iCloud Drive documents found. Please scan and tag documents first.")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onTapGesture {
            self.endEditing(true)
        }
    }

    private var deleteNavBarView: some View {
        Button(action: {
            self.viewModel.deleteDocument()
        }, label: {
            VStack {
                Image(systemName: "trash")
                Text("Delete")
                    .font(.system(size: 11.0))
            }
        })
    }

    private var saveNavBarView: some View {
        Button(action: {
            self.viewModel.saveDocument()
        }, label: {
            VStack {
                Image(systemName: "square.and.arrow.down")
                Text("Add")
                    .font(.system(size: 11.0))
            }
        })
    }

    private var pdfView: some View {
        PDFCustomView(self.viewModel.pdfDocument)
            .frame(maxWidth: .infinity, minHeight: 325.0, maxHeight: 325.0, alignment: .center)
    }

    private var datePicker: some View {
        HStack {
            Spacer()
            CustomDatePicker(date: $viewModel.date)
            Spacer()
        }
    }

    private var documentTags: some View {
        VStack(alignment: .leading) {
            Text("Document Tags")
                .font(.caption)
            TagListView(tags: $viewModel.documentTags, isEditable: true, isMultiLine: true, tapHandler: viewModel.documentTagTapped(_:))
                .font(.body)
            CustomTextField(text: $viewModel.documentTagInput,
                            placeholder: "Enter Tag",
                            suggestionView: UIView(),
                            onCommit: { _ in
                                self.viewModel.saveTag()
                            },
                            isFirstResponder: false)
                .padding(EdgeInsets(top: 4.0, leading: 0.0, bottom: 4.0, trailing: 0.0))
        }
    }

    private var suggestedTags: some View {
        VStack(alignment: .leading) {
            Text("Suggested Tags")
                .font(.caption)
            TagListView(tags: $viewModel.suggestedTags, isEditable: false, isMultiLine: true, tapHandler: viewModel.suggestedTagTapped(_:))
                .font(.body)
        }
    }
}
