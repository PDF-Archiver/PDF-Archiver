//
//  StorageSelectionView.swift
//  
//
//  Created by Julian Kahnert on 18.11.20.
//

import SwiftUI
import UniformTypeIdentifiers

struct StorageSelectionView: View {

    @Binding var selection: MoreTabViewModel.StorageType
    @State private var showDocumentPicker = false
    let onCompletion: (Result<URL, Error>) -> Void

    var body: some View {
        Form {
            ForEach(MoreTabViewModel.StorageType.allCases) { storageType in
                Section(footer: storageType.descriptionView) {
                    Button(action: {
                        selection = storageType
                        if storageType == .local {
                            showDocumentPicker = true
                        }
                    }) {
                        HStack {
                            Text(storageType.title)
                                .fixedSize()
                            Spacer()
                            if selection == storageType {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                #if os(macOS)
                Spacer(minLength: 8)
                #endif
            }
            .fileImporter(isPresented: $showDocumentPicker, allowedContentTypes: [UTType.folder], onCompletion: { result in
                switch result {
                case .success(let url):
                    // Securely access the URL to save a bookmark
                    guard url.startAccessingSecurityScopedResource() else {
                        // Handle the failure here.
                        return
                    }
                    onCompletion(.success(url))

                case .failure(let error):
                    onCompletion(.failure(error))
                }
                showDocumentPicker = false
            })
        }
    }
}

struct StorageSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        StorageSelectionView(selection: .constant(.local), onCompletion: { print($0) })
    }
}
