//
//  Settings.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 30.06.25.
//

import ArchiverModels
import ComposableArchitecture
import Shared
import SwiftUI
import StoreKit

@Reducer
struct Settings {

    @ObservableState
    struct State: Equatable {
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onContactSupportTapped
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .onContactSupportTapped:
                return .none
            }
        }
    }
}

struct SettingsView: View {
    @Bindable var store: StoreOf<Settings>
    private static let appId = 1433801905

    @Environment(\.requestReview) private var requestReview
    @Environment(\.dismiss) private var dismiss
//    @ObservedObject var viewModel: SettingsViewModel
//    @State private var showActivityView = false

    var body: some View {
        NavigationStack {
            Form {
                preferences
//                PremiumSectionView()
                moreInformation
            }
            .foregroundColor(.primary)
            .navigationTitle("Preferences & More")
            #if os(iOS)
            .navigationViewStyle(StackNavigationViewStyle())
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            #endif
        }
//        .sheet(isPresented: $showActivityView) {
//            // swiftlint:disable:next force_unwrapping
//            AppActivityView(activityItems: [URL(string: "https://apps.apple.com/app/pdf-archiver/id1433801905")!])
//        }
    }

    @ViewBuilder
    private var preferences: some View {
        Section {
//            Picker(selection: $viewModel.selectedQualityIndex, label: Text("PDF Quality")) {
//                ForEach(0..<viewModel.qualities.count, id: \.self) {
//                    Text(self.viewModel.qualities[$0])
//                }
//            }
//
//            Button {
//                viewModel.showArchiveTypeSelection = true
//            } label: {
//                HStack {
//                    Text("Storage")
//                    Spacer()
//                    Text(viewModel.selectedArchiveType.title)
//                }
//            }
//            .navigationDestination(isPresented: $viewModel.showArchiveTypeSelection) {
//                StorageSelectionView(selection: $viewModel.selectedArchiveType, onCompletion: viewModel.handleDocumentPicker)
//            }
//
//            Button("Open Archive Folder", action: viewModel.openArchiveFolder)
//                // if statement in view not possible, because the StorageSelectionView was not returning to the overview
//                // after the selection has changed.
//                .disabled(!PathManager.shared.archivePathType.isFileBrowserCompatible)
//                .opacity(PathManager.shared.archivePathType.isFileBrowserCompatible ? 1 : 0.3)
//            NavigationLink(destination: ExpertSettingsView(notSaveDocumentTagsAsPDFMetadata: $viewModel.notSaveDocumentTagsAsPDFMetadata,
//                                                           documentTagsNotRequired: $viewModel.documentTagsNotRequired,
//                                                           documentSpecificationNotRequired: $viewModel.documentSpecificationNotRequired,
//                                                           showPermissions: viewModel.showPermissions,
//                                                           resetApp: viewModel.resetApp)) {
//                Text("Advanced")
//            }
        } header: {
            Text("🛠 Preferences")
        }
    }

    private var moreInformation: some View {
        Section(header: Text("⁉️ More Information")) {
//            NavigationLink(destination: AboutMeView()) {
//                Text("About  👤")
//            }
//            Link("PDF Archiver Website  🖥", destination: viewModel.pdfArchiverUrl)
//            Link("Terms of Use", destination: viewModel.termsOfUseUrl)
//            SettingsViewModel.markdownView(for: "Terms & Privacy", withKey: "Privacy")
//            SettingsViewModel.markdownView(for: "Imprint", withKey: "Imprint")
            
            Button("Contact Support  🚑") {
                store.send(.onContactSupportTapped)
            }
            Button("Rate App ⭐️") {
                requestReview()
            }
            ShareLink(item: URL(string: "https://apps.apple.com/app/pdf-archiver/id1433801905")!) {
                Text("Share PDF Archiver 📱❤️🫵")
            }
        }
    }
}

#Preview("Settings", traits: .fixedLayout(width: 800, height: 600)) {
    SettingsView(
        store: Store(initialState: Settings.State()) {
            Settings()
                ._printChanges()
        }
    )
}
