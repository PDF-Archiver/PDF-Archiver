//
//  GeneralPane.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.09.26.
//

#if os(macOS)
import ArchiverModels
import ComposableArchitecture
import OSLog
import Shared
import SwiftUI
import UniformTypeIdentifiers

struct GeneralPane: View {
    @Bindable var store: StoreOf<Settings>

    var body: some View {
        Form {
            Section {
                SettingsRow(title: "PDF Quality", help: "Quality of the images that are converted into a PDF.") {
                    Picker("", selection: Binding(store.$pdfQuality)) {
                        ForEach(PDFQuality.allCases, id: \.self) { quality in
                            Text(quality.name, bundle: #bundle)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                SettingsRow(title: "Observed Folder", help: "PDF Archiver imports new documents from this folder.") {
                    HStack(spacing: 6) {
                        if let observedFolderURL = store.observedFolderURL {
                            Text(observedFolderURL.path)
                            Button {
                                store.send(.onObservedFolderRemoveTapped)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Button(String(localized: "Select", bundle: #bundle)) {
                                store.send(.onObserveredFolderSelectedTapped)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .fileImporter(isPresented: $store.showObservedFolderPicker, allowedContentTypes: [UTType.folder], onCompletion: { result in
            switch result {
            case .success(let url):
                guard url.startAccessingSecurityScopedResource() else {
                    return
                }
                store.send(.updateObservedFolder(url))

            case .failure(let error):
                Logger.settings.faultAndAssert("Failed to import a local folder: \(error)")
                NotificationCenter.default.postAlert(error)
            }
        })
    }
}

#Preview("GeneralPane", traits: .fixedLayout(width: 500, height: 300)) {
    GeneralPane(
        store: Store(initialState: Settings.State()) {
            Settings()
        }
    )
}
#endif
