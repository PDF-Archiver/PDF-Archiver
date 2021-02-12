//
//  DocumentDetailView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUIX

struct DocumentDetailView: View {
    @ObservedObject var viewModel: DocumentDetailViewModel
    var body: some View {
        VStack {
            documentDetails
            PDFCustomView(viewModel.pdfDocument)
        }
        .navigationBarTitle(Text(""), displayMode: .inline)
        .navigationBarItems(trailing: shareNavigationButton)
        .navigationBarItems(trailing: HStack(alignment: .bottom, spacing: 16) {
            #if !os(macOS)
            editButton
            shareNavigationButton
            #endif
        })
        .onAppear(perform: viewModel.viewAppeared)
        .sheet(isPresented: $viewModel.showActivityView) {
            #if !os(macOS)
            AppActivityView(activityItems: self.viewModel.activityItems)
            #endif
        }
    }

    var editButton: some View {
        Button(action: {
            NotificationCenter.default.edit(document: viewModel.document)
        }, label: {
            #if os(macOS)
            Label("Edit", systemImage: "pencil")
            #else
            Label("Edit", systemImage: "pencil")
                .labelStyle(VerticalLabelStyle())
            #endif
        })
    }

    private var documentDetails: some View {
        HStack {
            DocumentView(viewModel: viewModel.document, showTagStatus: false, multilineTagList: true)
            #if os(macOS)
            VStack(alignment: .leading) {
                editButton
                shareNavigationButton
            }
            #endif
        }
        .padding()
    }

    var shareNavigationButton: some View {
        Button(action: {
            #if os(macOS)
            NSWorkspace.shared.activateFileViewerSelecting([viewModel.document.path])
            #else
            self.viewModel.showActivityView = true
            #endif
        }, label: {
            #if os(macOS)
            Label("Show in Finder", systemImage: "doc.text.magnifyingglass")
            #else
            Label("Share", systemImage: "square.and.arrow.up")
                .labelStyle(VerticalLabelStyle())
            #endif
        })
    }
}
