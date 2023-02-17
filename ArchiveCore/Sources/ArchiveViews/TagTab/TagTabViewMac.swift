//
//  TagTabViewMac.swift
//  
//
//  Created by Julian Kahnert on 09.12.20.
//

import SwiftUI

#if os(macOS)
struct TagTabViewMac: View {
    @ObservedObject var viewModel: TagTabViewModel

    var body: some View {
        if viewModel.showLoadingView {
            LoadingView()
        } else {
            GeometryReader { proxy in
                HStack(spacing: 8) {
                    documentList
                        .frame(maxWidth: proxy.size.width * 0.3)
                        .clipped()

                    pdfView

                    documentInformation
                        .frame(maxWidth: proxy.size.width * 0.25)
                        .clipped()
                }
                .frame(width: proxy.frame(in: .global).width,
                       height: proxy.frame(in: .global).height)
            }
            .padding(8)
            .onDeleteCommand(perform: viewModel.deleteDocument)
        }
    }

    private var documentList: some View {
        VStack {
            Text("PDF Documents")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.paDarkRed)
            DocumentList(shouldShowDeleteButton: true,
                         currentDocument: $viewModel.currentDocument,
                         documents: $viewModel.documents)
        }
    }

    private var pdfView: some View {
        PDFCustomView(self.viewModel.pdfDocument)
    }

    @ViewBuilder
    private var documentInformation: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Document Attributes")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.paDarkRed)

            VStack(alignment: .leading, spacing: 4) {
                Label(viewModel.documentTitle ?? "", systemImage: "doc")
                    .opacity(viewModel.documentTitle == nil ? 0 : 1)
                Label(viewModel.documentSubtitle ?? "", systemImage: "doc.badge.plus")
                    .opacity(viewModel.documentSubtitle == nil ? 0 : 1)
            }
            .foregroundColor(.secondary)
            .font(.callout)
            .truncationMode(.middle)
            .minimumScaleFactor(0.8)
            .allowsTightening(true)
            .lineLimit(3)

            DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                .labelsHidden()
            TextField("Description", text: $viewModel.specification)
            ScrollView {
                TagListView(tags: $viewModel.documentTags,
                            isEditable: true,
                            isMultiLine: true,
                            tapHandler: viewModel.documentTagTapped(_:))
            }
            .frame(maxHeight: 175)
            HStack {
                Button(action: viewModel.saveDocument) {
                    Text("Save")
                        .padding(.horizontal, 44)
                }
                .frame(maxWidth: .infinity)
                .keyboardShortcut("s", modifiers: .command)
            }
            Text("Available Tags")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.paDarkRed)
            TextField("Enter Tag",
                      text: $viewModel.documentTagInput,
                      onCommit: viewModel.saveTag)
                .modifier(ClearButton(text: $viewModel.documentTagInput))
            ScrollView {
                TagListView(tags: $viewModel.suggestedTags,
                            isEditable: false,
                            isMultiLine: true,
                            tapHandler: viewModel.suggestedTagTapped(_:))
            }
            Spacer()
        }.padding(.horizontal, 10)
    }
}
#endif

#if DEBUG && os(macOS)
struct TagTabViewMac_Previews: PreviewProvider {
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
        TagTabViewMac(viewModel: viewModel)
            .previewLayout(.fixed(width: 1000, height: 650))
            .previewDevice("Mac")
    }
}
#endif
