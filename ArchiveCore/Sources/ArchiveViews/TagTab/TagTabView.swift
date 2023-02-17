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

    var body: some View {
        if viewModel.showLoadingView {
            LoadingView()
                .navigationBarHidden(true)
        } else if viewModel.currentDocument != nil {
            Stack(spacing: 8) {
                if horizontalSizeClass != .compact {
                    DocumentList(shouldShowDeleteButton: false, currentDocument: $viewModel.currentDocument, documents: $viewModel.documents)
                        .frame(maxWidth: 300)
                }
                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        PDFCustomView(self.viewModel.pdfDocument)
                            .frame(height: proxy.size.height * 0.6)
                        DocumentInformationForm(viewModel: viewModel)
                            .frame(height: proxy.size.height * 0.4)
                    }
                    .frame(width: proxy.frame(in: .global).width,
                           height: proxy.frame(in: .global).height)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    deleteNavBarView
                }
                ToolbarItem(placement: .principal) { // <3>
                    VStack(spacing: 1) {
                        Text(LocalizedStringKey(viewModel.documentTitle ?? "New Document"))
                            .minimumScaleFactor(0.7)
                            .allowsTightening(true)
                            .truncationMode(.middle)
                            .lineLimit(1)

                        Label(viewModel.documentSubtitle ?? "", systemImage: "doc.badge.plus")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .minimumScaleFactor(0.5)
                            .allowsTightening(true)
                            .lineLimit(1)
                            .opacity(viewModel.documentSubtitle == nil ? 0 : 1)
                            .labelStyle(self.paLabelStyle())
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    saveNavBarView
                }
            }
        } else {
            PlaceholderView(name: "No iCloud Drive documents found. Please scan and tag documents first.")
                .navigationBarHidden(true)
        }
    }

    private var deleteNavBarView: some View {
        Button(action: {
            self.viewModel.deleteDocument()
        }, label: {
            Label("Delete", systemImage: "trash")
                .labelStyle(VerticalLabelStyle())
                .foregroundColor(.red)
                .padding(.horizontal, 24)
        })
        .disabled(viewModel.currentDocument == nil)
        .keyboardShortcut(.delete, modifiers: .command)
    }

    private var saveNavBarView: some View {
        Button(action: {
            self.viewModel.saveDocument()
        }, label: {
            Label("Add", systemImage: "square.and.arrow.down")
                .labelStyle(VerticalLabelStyle())
                .padding(.horizontal, 24)
        })
        .disabled(viewModel.currentDocument == nil)
        .keyboardShortcut("s", modifiers: .command)
    }

    func paLabelStyle() -> some LabelStyle {
        if #available(iOS 14.5, *) {
            return TitleAndIconLabelStyle.titleAndIcon
        } else {
            return TitleOnlyLabelStyle.titleOnly
        }
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

// extension LabelStyle where Self == <#Type#> {
//    static var paLabelStyle: any LabelStyle {
//        if #available(iOS 14.5, *) {
//            return TitleAndIconLabelStyle.titleAndIcon
//        } else {
//            return TitleOnlyLabelStyle.titleOnly
//        }
//    }
// }
