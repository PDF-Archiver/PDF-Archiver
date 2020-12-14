//
//  TagTabView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 02.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

#if os(iOS)
struct TagTabView: View {

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var viewModel: TagTabViewModel

    // TODO: do we need this?
    // trigger a reload of the view, when the device rotation changes
//    @EnvironmentObject var orientationInfo: OrientationInfo

    var body: some View {
        if viewModel.showLoadingView {
            LoadingView()
                .navigationBarHidden(true)
                .emittingError(viewModel.error)
        } else if viewModel.currentDocument != nil {
            Stack(spacing: 8) {
                if horizontalSizeClass != .compact {
                    documentsList
                }
                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        PDFCustomView(self.viewModel.pdfDocument)
                            .frame(height: proxy.size.height * 0.6)
                        DocumentInformationForm(date: $viewModel.date,
                                                specification: $viewModel.specification,
                                                tags: $viewModel.documentTags,
                                                tagInput: $viewModel.documentTagInput,
                                                suggestedTags: $viewModel.suggestedTags)
                            .frame(height: proxy.size.height * 0.4)
                    }
                    .frame(width: proxy.frame(in: .global).width,
                           height: proxy.frame(in: .global).height)
                }
            }
            .navigationBarHidden(false)
            .navigationBarTitle(Text("Document"), displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    deleteNavBarView
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    saveNavBarView
                }
            }
            .emittingError(viewModel.error)
        } else {
            PlaceholderView(name: "No iCloud Drive documents found. Please scan and tag documents first.")
                .navigationBarHidden(true)
                .emittingError(viewModel.error)
        }
    }

    private var deleteNavBarView: some View {
        Button(action: {
            self.viewModel.deleteDocument()
        }, label: {
//            #if os(macOS)
//            HStack {
//                Image(systemName: "trash")
//                Text("Delete")
//                    .font(.caption)
//            }
//            .padding(.horizontal, 24)
//            #else
            VStack {
                Image(systemName: "trash")
                Text("Delete")
                    .font(.caption)
            }
            .padding(.horizontal, 24)
        })
        .disabled(viewModel.currentDocument == nil)
    }

    private var saveNavBarView: some View {
        Button(action: {
            self.viewModel.saveDocument()
        }, label: {
//            #if os(macOS)
//            HStack {
//                Image(systemName: "square.and.arrow.down")
//                Text("Add")
//                    .font(.caption)
//            }
//            .padding(.horizontal, 24)
//            #else
            VStack {
                Image(systemName: "square.and.arrow.down")
                Text("Add")
                    .font(.caption)
            }
            .padding(.horizontal, 24)
        })
        .disabled(viewModel.currentDocument == nil)
    }

    // MARK: Component Groups

    private var documentsList: some View {
//        VStack {
//            Text("Tagged: \(viewModel.taggedUntaggedDocuments)")
//                .font(Font.headline)
//                .padding()
//            List {
//                ForEach(viewModel.documents) { document in
//                    HStack {
//                        Circle()
//                            .fill(Color.systemBlue)
//                            .frame(width: 8, height: 8)
//                            .opacity(document == self.viewModel.currentDocument ? 1 : 0)
//                        DocumentView(viewModel: document, showTagStatus: true)
//                    }
//                    .contentShape(Rectangle())
//                    .onTapGesture {
//                       self.viewModel.currentDocument = document
//                    }
//                }
//            }
//        }
        DocumentList(currentDocument: $viewModel.currentDocument, documents: $viewModel.documents)
        .frame(maxWidth: 300)
    }
}
#endif

#if DEBUG && os(iOS)
struct TagTabView_Previews: PreviewProvider {
    static var viewModel: TagTabViewModel = {
        let model = TagTabViewModel()
        model.showLoadingView = false
        model.date = Date()
        model.documents = [
            Document.create(),
            Document.create(),
            Document.create()
        ]
        model.documentTags = ["bill", "letter"]
        model.suggestedTags = ["tag1", "tag2", "tag3"]
        model.currentDocument = Document.create()
        return model
    }()

    static var previews: some View {
        TagTabView(viewModel: viewModel)
            .makeForPreviewProvider()
    }
}
#endif
