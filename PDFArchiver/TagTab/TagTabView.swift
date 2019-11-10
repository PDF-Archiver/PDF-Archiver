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
        NavigationView {
            if viewModel.currentDocument != nil {
                VStack {
                    pdfView
                    Form {
                        DatePicker("Date",
                                   selection: $viewModel.date,
                                   displayedComponents: .date)
                        TextField("Description", text: $viewModel.specification)
                        documentTags
                        suggestedTags
                    }
                }
                .keyboardObserving()
                .navigationBarTitle(Text("Document"), displayMode: .inline)
                .navigationBarItems(leading: deleteNavBarView, trailing: saveNavBarView)
            } else {
                // TODO: add an empty view
                Text("Empty View")
            }
        }
    }

    private var deleteNavBarView: some View {
        Button(action: {
            print("Delete")
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
            print("save")
        }, label: {
            VStack {
                Image(systemName: "square.and.arrow.down")
                Text("Add")
                    .font(.system(size: 11.0))
            }
        })
    }

    private var pdfView: some View {
        GeometryReader { proxy in
            PDFCustomView(self.viewModel.pdfDocument)
                .frame(maxWidth: .infinity, idealHeight: proxy.size.height * 0.40, alignment: .center)
        }
    }

    private var documentTags: some View {
        VStack(alignment: .leading) {
            Text("Document Tags")
                .font(.caption)
            TagListView(tags: $viewModel.documentTags, isEditable: true, isMultiLine: true)
                .font(.body)
            // TODO: add action
            TextField("Enter Tag",
                text: $viewModel.documentTagInput,
                onEditingChanged: {value in

                },
                onCommit: {
                    print("Input finished!")
                })
        }
    }

    private var suggestedTags: some View {
        VStack(alignment: .leading) {
            Text("Suggested Tags")
                .font(.caption)
            TagListView(tags: $viewModel.suggestedTags, isEditable: false, isMultiLine: true)
                .font(.body)
        }
    }
}
