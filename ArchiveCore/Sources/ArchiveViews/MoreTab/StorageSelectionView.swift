//
//  StorageSelectionView.swift
//  
//
//  Created by Julian Kahnert on 18.11.20.
//

import SwiftUI

struct StorageSelectionView: View {

    @Binding var selection: MoreTabViewModel.StorageType

    var body: some View {
        Form {
            ForEach(MoreTabViewModel.StorageType.allCases) { storageType in
                Section(footer: storageType.descriptionView) {
                    Button(action: {
                        selection = storageType
                    }) {
                        HStack {
                            Text(storageType.title)
                                .foregroundColor(.label)
                            Spacer()
                            if selection == storageType {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                #if os(macOS)
                Spacer(minLength: 28)
                #endif
            }
        }
    }
}

struct StorageSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        #if os(macOS)
        StorageSelectionView(selection: .constant(.local))
        #else
        StorageSelectionView(selection: .constant(.appContainer))
        #endif
    }
}
