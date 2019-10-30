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
            .navigationBarTitle(Text("Search"))
        }
    }

    var searchView: some View {
        SearchField(searchText: $viewModel.searchText,
                    scopes: $viewModel.years,
                    selectionIndex: $viewModel.scopeSelecton)
            .padding(EdgeInsets(top: 0.0, leading: 16.0, bottom: 0.0, trailing: 16.0))
    }

    var documentsView: some View {
        List {
            ForEach(viewModel.documents) { document in
                DocumentView(viewModel: DocumentViewModel(document))
            }
        }
    }
}

struct ArchiveView_Previews: PreviewProvider {

    static let viewModel = ArchiveViewModel()

    static var previews: some View {
        ArchiveView(viewModel: viewModel)
    }
}
