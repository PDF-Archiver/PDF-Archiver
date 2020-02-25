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

    // trigger a reload of the view, when the device rotation changes
    @EnvironmentObject var orientationInfo: OrientationInfo

    var body: some View {
        NavigationView {
            if viewModel.showLoadingView {
                LoadingView()
            } else {
                if viewModel.currentDocument != nil {
                    Stack {
                        if self.shouldShowDocumentList() {
                            self.documentsList
                        }
                        self.pdfView
                        self.documentInformation
                    }
                    .keyboardObserving(offset: 16.0)
                    .padding(EdgeInsets(top: 0.0, leading: 8.0, bottom: 0.0, trailing: 8.0))
                    .navigationBarTitle(Text("Document"), displayMode: .inline)
                    .navigationBarItems(leading: deleteNavBarView, trailing: saveNavBarView)
                } else {
                    PlaceholderView(name: "No iCloud Drive documents found. Please scan and tag documents first.")
                }
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

    // MARK: Component Groups

    private var documentsList: some View {
        VStack {
            Text("Tagged: \(viewModel.taggedUntaggedDocuments)")
                .font(Font.headline)
            List {
                ForEach(viewModel.documents) { document in
                    HStack {
                        Circle()
                            .fill(Color.systemBlue)
                            .frame(width: 8, height: 8)
                            .opacity(document == self.viewModel.currentDocument ? 1 : 0)
                        DocumentView(viewModel: DocumentViewModel(document), showTagStatus: true)
                    }
                    .onTapGesture {
                       self.viewModel.currentDocument = document
                    }
                }
            }
        }
        .frame(maxWidth: 250)
    }

    private var pdfView: some View {
        PDFCustomView(self.viewModel.pdfDocument)
            .frame(maxWidth: .infinity, minHeight: 325.0, maxHeight: .infinity, alignment: .center)
    }

    private var documentInformation: some View {
        VStack(alignment: .leading, spacing: 16.0) {
            datePicker
            TextField("Description", text: $viewModel.specification)
                .modifier(ClearButton(text: $viewModel.specification))
            documentTags
            suggestedTags
            Spacer()
        }
        .frame(maxWidth: 350)
    }

    // MARK: Single Components

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
                            onCommit: viewModel.saveTag,
                            isFirstResponder: false,
                            suggestions: viewModel.inputAccessoryViewSuggestions)
                .frame(maxHeight: 22)
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

    private func shouldShowDocumentList() -> Bool {
        let screenSize = UIScreen.main.bounds.size
        return UIDevice.current.userInterfaceIdiom != .phone && screenSize.height < screenSize.width
    }
}
