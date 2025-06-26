//
//  SettingsViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 13.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable force_unwrapping

import Combine
import SwiftUI
#if os(iOS)
import CoreServices
#endif

@MainActor
final class SettingsViewModel: ObservableObject, Log {
    static let appVersion = AppEnvironment.getFullVersion()

    static func markdownView(for title: LocalizedStringKey, withKey key: String, withScrollView scrollView: Bool = true) -> some View {
        guard let url = Bundle.main.url(forResource: key, withExtension: "md"),
              let markdown = try? String(contentsOf: url, encoding: .utf8) else { preconditionFailure("Could not fetch file \(key)") }

        return MarkdownView(title: title, markdown: markdown, scrollView: scrollView)
    }

    let qualities: [LocalizedStringKey] = ["100% - Lossless 🤯", "75% - Good 👌 (Default)", "50% - Normal 👍", "25% - Small 💾"]
    let storageTypes: [String] = StorageType.allCases.map(\.title).map { "\($0)" }
    @Published var selectedQualityIndex = UserDefaults.PDFQuality.toIndex(UserDefaults.pdfQuality) ?? UserDefaults.PDFQuality.defaultQualityIndex
    @Published var notSaveDocumentTagsAsPDFMetadata = UserDefaults.notSaveDocumentTagsAsPDFMetadata
    @Published var documentTagsNotRequired = UserDefaults.documentTagsNotRequired
    @Published var documentSpecificationNotRequired = UserDefaults.documentSpecificationNotRequired
    @Published var selectedArchiveType = StorageType.getCurrent()
    @Published var showArchiveTypeSelection = false
    @Published var newArchiveUrl: URL?

    #if os(macOS)
    @Published var finderTagUpdateProgress: Double = 0
    @Published var observedFolderURL: URL? = UserDefaults.observedFolderURL
    #endif

    var pdfArchiverUrl: URL {
        URL(string: "https://pdf-archiver.io")!
    }

    var termsOfUseUrl: URL {
        URL(string: "https://pdf-archiver.io/terms")!
    }

    var privacyPolicyUrl: URL {
        URL(string: "https://pdf-archiver.io/privacy")!
    }

    private var disposables = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "MoreTabViewModel", qos: .userInitiated)

    init() {
        $selectedQualityIndex
            .sink { selectedQuality in
                UserDefaults.pdfQuality = UserDefaults.PDFQuality.allCases[selectedQuality]
            }
            .store(in: &disposables)

        $notSaveDocumentTagsAsPDFMetadata
            .sink { value in
                UserDefaults.notSaveDocumentTagsAsPDFMetadata = value
            }
            .store(in: &disposables)

        $documentTagsNotRequired
            .sink { value in
                UserDefaults.documentTagsNotRequired = value
            }
            .store(in: &disposables)

        $documentSpecificationNotRequired
            .sink { value in
                UserDefaults.documentSpecificationNotRequired = value
            }
            .store(in: &disposables)

        $selectedArchiveType
            .dropFirst()
            .sink { selectedArchiveType in
                let type: PathManager.ArchivePathType
                switch selectedArchiveType {
                case .iCloudDrive:
                    type = .iCloudDrive
                #if os(iOS)
                case .appContainer:
                    type = .appContainer
                #endif
                case .local:
                    if let newArchiveUrl = self.newArchiveUrl {
                        type = .local(newArchiveUrl)
                        self.newArchiveUrl = nil
                    } else {
                        // document picker will be opened
                        return
                    }
                }
                self.handle(newType: type)
            }
            .store(in: &disposables)
    }

    #if !os(macOS)
    func showPermissions() {
        log.info("More table view show: app permissions")
        guard let settingsAppURL = URL(string: UIApplication.openSettingsURLString) else { fatalError("Could not find settings url!") }
        open(settingsAppURL)
    }
    #endif

    func handleDocumentPicker(result: Result<URL, any Error>) {
        switch result {
        case .success(let selectedUrl):
            self.newArchiveUrl = selectedUrl
            // trigger archive type change
            let tmp = self.selectedArchiveType
            self.selectedArchiveType = tmp
        case .failure(let error):
            self.log.errorAndAssert("Found error in document picker", metadata: ["error": "\(error)"])
        }
    }

    private func handle(newType type: PathManager.ArchivePathType) {
        Task {
            do {
                try PathManager.shared.setArchiveUrl(with: type)

                let archiveUrl = try PathManager.shared.getArchiveUrl()
                let untaggedUrl = try PathManager.shared.getUntaggedUrl()

                self.showArchiveTypeSelection = false
                await ArchiveStore.shared.update(archiveFolder: archiveUrl, untaggedFolders: [untaggedUrl])
            } catch {
                NotificationCenter.default.postAlert(error)
            }
        }
    }

    func resetApp() {
        log.info("More table view show: reset app")
        // remove all temporary files
        try? FileManager.default.removeItem(at: Constants.tempDocumentURL)

        // remove all user defaults
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.appGroup.removePersistentDomain(forName: bundleIdentifier)
        } else {
            log.error("Bundle Identifier not found.")
        }

        NotificationCenter.default.createAndPost(title: "Reset App",
                                                 message: "Please restart the app to complete the reset.",
                                                 primaryButtonTitle: "OK")
    }

    func openArchiveFolder() {
        Task {
            do {
#if os(macOS)
                let url = try PathManager.shared.getArchiveUrl()
#else
                let archiveUrl = try PathManager.shared.getArchiveUrl()
                // dropFirst uses the index that's why we need -1
                let pathWithoutScheme = archiveUrl.absoluteString.dropFirst("files://".count - 1)
                guard let url = URL(string: "shareddocuments://\(pathWithoutScheme)") else { return }
#endif
                open(url)
            } catch {
                NotificationCenter.default.postAlert(error)
            }
        }
    }

    #if os(macOS)
    func updateFinderTags(from documents: [Document]) {
        finderTagUpdateProgress = 0

        struct DocumentTags {
            let url: URL
            let tags: Set<String>
        }

        let totalDocumentsCount = Double(documents.count)
        let taggedDocuments = documents
            .filter(\.isTagged)
            .map { document in
                DocumentTags(url: document.url, tags: Set(document.tags))
            }

        Task(priority: .background) {
            var processedDocumentsCount = 0
            for taggedDocument in taggedDocuments {
                let sortedTags = Array(taggedDocument.tags).sorted()
                taggedDocument.url.setFileTags(sortedTags)
                processedDocumentsCount += 1

                let tmp = Double(processedDocumentsCount) / totalDocumentsCount
                await MainActor.run {
                    self.finderTagUpdateProgress = tmp
                }
            }
            await MainActor.run {
                self.finderTagUpdateProgress = 0
            }
        }
    }

    func clearObservedFolder() {
        observedFolderURL = nil
        UserDefaults.observedFolderURL = nil
        queue.async {
            Task {
                do {
                    try await ArchiveStore.shared.reloadArchiveDocuments()
                } catch {
                    NotificationCenter.default.postAlert(error)
                }
            }
        }
    }

    func selectObservedFolder() {
        let openPanel = NSOpenPanel()
        openPanel.title = NSLocalizedString("Choose the observed folder", comment: "")
        openPanel.showsHiddenFiles = false
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true
        openPanel.begin { response in
            Task {
                await MainActor.run {
                    guard response == .OK,
                          let url = openPanel.url else { return }
                    self.observedFolderURL = url
                    UserDefaults.observedFolderURL = url
                    self.queue.async {
                        Task {
                            do {
                                try await ArchiveStore.shared.reloadArchiveDocuments()
                            } catch {
                                NotificationCenter.default.postAlert(error)
                            }
                        }
                    }
                }
            }
        }
    }
    #endif
}
