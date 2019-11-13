//
//  ArchiveView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 27.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import SwiftUI

struct ArchiveView: View {
    @ObservedObject var viewModel: ArchiveViewModel

    var body: some View {
        NavigationView {
            VStack {
                searchView
                documentsView
            }
            .navigationBarTitle(Text("Documents"))
            emptyView
        }
        // force list show: https://stackoverflow.com/a/58371424/10026834
        .padding()
    }

    var searchView: some View {
        SearchField(searchText: $viewModel.searchText,
                    scopes: $viewModel.years,
                    selectionIndex: $viewModel.scopeSelecton)
    }

    var documentsView: some View {
        List {
            ForEach(viewModel.documents) { document in
                if document.downloadStatus == .local {
                    NavigationLink(destination: ArchiveViewModel.createDetail(with: document)) {
                        DocumentView(viewModel: DocumentViewModel(document))
                    }
                } else {
                    DocumentView(viewModel: DocumentViewModel(document))
                        .onTapGesture {
                            self.viewModel.tapped(document)
                        }
                }
            }.onDelete(perform: viewModel.delete(at:))
        }
    }

    var emptyView: some View {
        // TODO: add real empty view
        Text("Empty View")
    }
}

struct ArchiveView_Previews: PreviewProvider {

    static let viewModel = ArchiveViewModel()

    static var previews: some View {
        ArchiveView(viewModel: viewModel)
    }
}
