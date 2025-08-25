//
//  StorageSelectionView.swift
//  
//
//  Created by Julian Kahnert on 18.11.20.
//

import ArchiverModels
import SwiftUI
import UniformTypeIdentifiers

struct StorageSelectionView: View {

    @Binding var selection: StorageType
    @State private var showDocumentPicker = false
    let onCompletion: (Result<URL, any Error>) -> Void

    var body: some View {
        Form {
            ForEach(StorageType.allCases) { storageType in
                Section(footer: storageType.descriptionView) {
                    Button {
                        selection = storageType
                        if storageType == .local {
                            showDocumentPicker = true
                        }
                    } label: {
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
            Text("PDF Archiver is not a backup solution. Please make backups of the archieved PDFs regularly.")
                .foregroundStyle(.secondary)
                .font(.footnote)
                .padding(.vertical)
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

#Preview {
    StorageSelectionView(selection: .constant(.local), onCompletion: { print($0) })
}
