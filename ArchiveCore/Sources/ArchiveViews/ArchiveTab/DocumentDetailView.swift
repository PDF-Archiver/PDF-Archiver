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
            DocumentView(viewModel: viewModel.document, showTagStatus: false, multilineTagList: true)
                .padding()
            PDFCustomView(viewModel.pdfDocument)
        }
        .navigationBarTitle(Text(""), displayMode: .inline)
        .navigationBarItems(trailing: shareNavigationButton)
//        .navigationBarItems(trailing: HStack(alignment: .bottom, spacing: 16) {
//            editButton
//            shareNavigationButton
//        })
        .onAppear(perform: viewModel.viewAppeared)
        .sheet(isPresented: $viewModel.showActivityView) {
            #if !os(macOS)
            AppActivityView(activityItems: self.viewModel.activityItems)
            #endif
        }
    }

//    var editButton: some View {
//        Button(action: {}, label: {
//            Label("Edit", systemImage: "pencil")
//                .labelStyle(VerticalLabelStyle())
//        })
//    }

    var shareNavigationButton: some View {
        Button(action: {
            #if os(macOS)
            NSWorkspace.shared.activateFileViewerSelecting([viewModel.document.path])
            #else
            self.viewModel.showActivityView = true
            #endif
        }, label: {
            Label("Share", systemImage: "square.and.arrow.up")
                .labelStyle(VerticalLabelStyle())
        })
    }
}
