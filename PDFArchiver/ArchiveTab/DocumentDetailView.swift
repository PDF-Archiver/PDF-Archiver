//
//  DocumentDetailView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct DocumentDetailView: View {
    let viewModel: DocumentDetailViewModel
    var body: some View {
        VStack {
            DocumentView(viewModel: DocumentViewModel(viewModel.document))
                .padding()
            PDFCustomView(viewModel.pdfDocument)
        }
        .navigationBarTitle("Document", displayMode: .inline)
        .navigationBarItems(trailing: shareNavigationButton)
        .onAppear(perform: viewModel.viewAppeared)
    }

    var shareNavigationButton: some View {
        Button(action: {
            print("share button tapped!")
        }, label: {
            Image(systemName: "square.and.arrow.up")
        })
    }
}

//struct DocumentDetailView_Previews: PreviewProvider {
//    static var previews: some View {
//        DocumentDetailView()
//    }
//}
