//
//  TagTabView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 02.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct TagTabView: View {
    @ObservedObject var viewModel: TagTabViewModel

    var body: some View {
        NavigationView {
            if viewModel.currentDocument != nil {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 8.0) {
                    pdfView
                    datePicker
                    specification
                    documentTags
                    suggestedTags
                }
            }
            .padding(EdgeInsets(top: 0.0, leading: 16.0, bottom: 32.0, trailing: 16.0))
            .navigationBarTitle("Tag", displayMode: .inline)
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
                Text("Save")
                    .font(.system(size: 11.0))
            }
        })
    }

    private var pdfView: some View {
        PDFCustomView(viewModel.pdfDocument)
            .frame(maxWidth: .infinity, idealHeight: 450.0, alignment: .center)
    }

    private var datePicker: some View {
        DatePicker(selection: $viewModel.date,
                   displayedComponents: .date) {
                    EmptyView()
                }
                .frame(maxWidth: .infinity, maxHeight: 120.0, alignment: .center)
    }

    private var specification: some View {
        VStack(alignment: .leading) {
            Text("Description")
                .font(.caption)
            TextField("Enter Description",
                      text: $viewModel.specification)
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
