//
//  ArchiveView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 27.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import SwiftUI
import SwiftUIX

struct ArchiveView: View {
    @ObservedObject var viewModel: ArchiveViewModel

    var body: some View {
        NavigationView {
            if viewModel.showLoadingView {
                loadingView
            } else {
                VStack {
                    searchView
                    documentsView
                }
                .navigationBarTitle(Text("Documents"))
            }
            emptyView
        }
        // force list show: https://stackoverflow.com/a/58371424/10026834
        .padding(EdgeInsets(top: 0.0, leading: 8.0, bottom: 0.0, trailing: 8.0))
    }

    var loadingView: some View {
        VStack(alignment: .center, spacing: 32.0) {
            ActivityIndicator()
                .animated(true)
            Text("Loading documents ...")
        }
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
        .onTapGesture {
            self.endEditing(true)
        }
    }

    var emptyView: some View {
        let name: LocalizedStringKey
        if viewModel.documents.isEmpty {
            name = "No iCloud Drive documents found. Please scan and tag documents first or change filter."
        } else {
            name = "Select a document."
        }
        return PlaceholderView(name: name)
    }
}

struct ArchiveView_Previews: PreviewProvider {

    static let viewModel = ArchiveViewModel()

    static var previews: some View {
        ArchiveView(viewModel: viewModel)
    }
}
