//
//  StorageSelectionView.swift
//  
//
//  Created by Julian Kahnert on 18.11.20.
//

import SwiftUI
import SwiftUILib_DocumentPicker
#if os(iOS)
import MobileCoreServices
#endif

struct StorageSelectionView: View {

    @Binding var selection: MoreTabViewModel.StorageType
	@Binding var showDocumentPicker: Bool
	@Binding var urlDocumentPicker: URL?

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
			.documentPicker(
				isPresented: $showDocumentPicker,
				documentTypes: [kUTTypeFolder as String /* "public.folder" */ ], onDocumentsPicked: { urls in
					guard let url = urls.first else { return }
					urlDocumentPicker = url
				}
			)
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
