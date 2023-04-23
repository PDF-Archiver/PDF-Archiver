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
#if os(iOS)
	@Binding var showDocumentPicker: Bool
	@Binding var urlDocumentPicker: URL?
#endif

    var body: some View {
        Form {
            ForEach(MoreTabViewModel.StorageType.allCases) { storageType in
                Section(footer: storageType.descriptionView) {
                    Button(action: {
                        selection = storageType
                    }) {
                        HStack {
                            Text(storageType.title)
                                .fixedSize()
                                .foregroundColor(.label)
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
			#if os(iOS)
			.fileImporter(isPresented: $showDocumentPicker, allowedContentTypes: [UTType.folder], onCompletion: { result in
				switch result {
					case .success(let url):
						// Securely access the URL to save a bookmark
						guard url.startAccessingSecurityScopedResource() else {
							// Handle the failure here.
							return
						}
						urlDocumentPicker = url

					case .failure(let error):
						print("Download picker error: \(error)")
				}
			})
			#endif
        }
    }
}

struct StorageSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        #if os(macOS)
        StorageSelectionView(selection: .constant(.local))
        #else
		StorageSelectionView(selection: .constant(.appContainer), showDocumentPicker: .constant(false), urlDocumentPicker: .constant(nil))
        #endif
    }
}
