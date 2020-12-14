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
            .frame(proxy.size)
        }
        .padding(8)
    }
    
    private var documentList: some View {
        DocumentList(currentDocument: $viewModel.currentDocument,
                     documents: $viewModel.documents)
    }
    
    private var pdfView: some View {
        PDFCustomView(self.viewModel.pdfDocument)
    }
    
    @ViewBuilder
    private var documentInformation: some View {
        
        VStack(alignment: .leading, spacing: 16) {
            Text("Document Attributes")
                .font(.title)
            DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                .labelsHidden()
            //                .padding(.horizontal, 16)
            TextField("Description", text: $viewModel.specification)
            TagListView(tags: $viewModel.documentTags,
                        isEditable: true,
                        isMultiLine: true,
                        tapHandler: documentTagTapped(_:))
                .font(.caption)
                .frame(maxHeight: 175)
            HStack {
                Spacer()
                Button("Save", action: saveButtonTapped)
                Spacer()
            }
            Text("Available Tags")
                .font(.title)
            TextField("Search and add", text: $viewModel.documentTagInput)
            TagListView(tags: $viewModel.suggestedTags,
                        isEditable: false,
                        isMultiLine: true,
                        tapHandler: documentTagTapped(_:))
                .font(.caption)
            Spacer()
        }.padding(.horizontal, 10)
    }
    
    private func saveButtonTapped() {
        print("Save Button Tapped")
    }
    
    private func documentTagTapped(_ tag: String) {
        print(tag)
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
        TagTabViewMac(viewModel: viewModel)            .previewLayout(.fixed(width: 1000, height: 650))
            .previewDevice("Mac")
    }
}
#endif
