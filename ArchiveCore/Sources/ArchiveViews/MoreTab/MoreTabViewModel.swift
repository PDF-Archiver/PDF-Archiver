//
//  MoreTabViewModel.swift
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

public class MoreTabViewModel: ObservableObject, Log {
    public static let appVersion = AppEnvironment.getFullVersion()

    public static func markdownView(for title: LocalizedStringKey, withKey key: String) -> some View {
        guard let url = Bundle.main.url(forResource: key, withExtension: "md"),
              let markdown = try? String(contentsOf: url) else { preconditionFailure("Could not fetch file \(key)") }

        return MarkdownView(title: title, markdown: markdown)
    }

    let qualities: [String] = ["100% - Lossless 🤯", "75% - Good 👌 (Default)", "50% - Normal 👍", "25% - Small 💾"]
    let storageTypes: [String] = StorageType.allCases.map(\.title).map { "\($0)" }
    @Published var selectedQualityIndex = UserDefaults.PDFQuality.toIndex(UserDefaults.pdfQuality) ?? UserDefaults.PDFQuality.defaultQualityIndex
    @Published var notSaveDocumentTagsAsPDFMetadata = UserDefaults.notSaveDocumentTagsAsPDFMetadata
    @Published var documentTagsNotRequired = UserDefaults.documentTagsNotRequired
    @Published var documentSpecificationNotRequired = UserDefaults.documentSpecificationNotRequired
    @Published var selectedArchiveType = StorageType.getCurrent()
    @Published var showArchiveTypeSelection = false
    @Published var subscriptionStatus: LocalizedStringKey = "Inactive ❌"
    @Published var statisticsViewModel: StatisticsViewModel
    @Published var newArchiveUrl: URL?
    #if os(macOS)
    @Published var observedFolderURL: URL? = UserDefaults.observedFolderURL
    #endif
	@Published var showDocumentPicker: Bool = false

    var manageSubscriptionUrl: URL {
        URL(string: "https://apps.apple.com/account/subscriptions")!
    }

    var pdfArchiverUrl: URL {
        URL(string: "https://pdf-archiver.io")!
    }

    private let iapService: IAPServiceAPI
    private let archiveStore: ArchiveStoreAPI
    private var disposables = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "MoreTabViewModel", qos: .userInitiated)
    private let queueUtility = DispatchQueue(label: "MoreTabViewModel-utility", qos: .utility)

    public init(iapService: IAPServiceAPI, archiveStore: ArchiveStoreAPI) {
        self.iapService = iapService
        self.archiveStore = archiveStore
        self.statisticsViewModel = StatisticsViewModel(documents: archiveStore.documents)

        archiveStore.documentsPublisher
            .receive(on: queueUtility)
            .map(StatisticsViewModel.init(documents: ))
            .receive(on: DispatchQueue.main)
            .assign(to: &$statisticsViewModel)

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

        #if os(macOS)
        $selectedArchiveType
            .dropFirst()
            .sink { selectedArchiveType in
                let type: PathManager.ArchivePathType
                switch selectedArchiveType {
                    case .iCloudDrive:
                        type = .iCloudDrive
                    case .local:
                        if let newArchiveUrl = self.newArchiveUrl {
                            type = .local(newArchiveUrl)
                            self.newArchiveUrl = nil
                        } else {
                            self.chooseArchivePanel()
                            return
                        }
                }
                self.handle(newType: type)
            }
            .store(in: &disposables)
        #else
        $selectedArchiveType
            .dropFirst()
            .sink { selectedArchiveType in
                let type: PathManager.ArchivePathType
                switch selectedArchiveType {
                    case .iCloudDrive:
                        type = .iCloudDrive
                    case .appContainer:
                        type = .appContainer
					case .local:
						if let newArchiveUrl = self.newArchiveUrl {
							type = .local(newArchiveUrl)
							self.newArchiveUrl = nil
						} else {
							self.showDocumentPicker = true
							return
						}
                }
				self.handle(newType: type)
            }
            .store(in: &disposables)
        #endif

        iapService.appUsagePermittedPublisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { appUsagePermitted in
                self.subscriptionStatus = appUsagePermitted ? "Active ✅" : "Inactive ❌"
            }
            .store(in: &disposables)
    }

    func showIntro() {
        log.info("More table view show: intro")
        NotificationCenter.default.post(name: .introChanges, object: true)
    }

    #if !os(macOS)
    func showPermissions() {
        log.info("More table view show: app permissions")
        guard let settingsAppURL = URL(string: UIApplication.openSettingsURLString) else { fatalError("Could not find settings url!") }
        open(settingsAppURL)
    }
    #endif

    #if os(macOS)
    private func chooseArchivePanel() {
        let openPanel = NSOpenPanel()
        openPanel.title = NSLocalizedString("Choose the archive folder", comment: "")
        openPanel.showsResizeIndicator = false
        openPanel.showsHiddenFiles = false
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true
        openPanel.begin { response in
            guard response == .OK,
                  let url = openPanel.url else { return }
            self.newArchiveUrl = url
            // trigger archive type change
            let tmp = self.selectedArchiveType
            self.selectedArchiveType = tmp
        }
    }
    #endif
	#if os(iOS)
	func handleDocumentPicker(selectedUrl: URL) {
		self.newArchiveUrl = selectedUrl
		let tmp = self.selectedArchiveType
		self.selectedArchiveType = tmp
	}
	#endif

    private func handle(newType type: PathManager.ArchivePathType) {
        do {
            try PathManager.shared.setArchiveUrl(with: type)

            let archiveUrl = try PathManager.shared.getArchiveUrl()
            let untaggedUrl = try PathManager.shared.getUntaggedUrl()

            self.showArchiveTypeSelection = false
            queue.async {
                self.archiveStore.update(archiveFolder: archiveUrl, untaggedFolders: [untaggedUrl])
            }
        } catch {
            NotificationCenter.default.postAlert(error)
        }
    }

    func resetApp() {
        log.info("More table view show: reset app")
        // remove all temporary files
        try? FileManager.default.removeItem(at: PathConstants.tempImageURL)

        // remove all user defaults
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.appGroup.removePersistentDomain(forName: bundleIdentifier)
        } else {
            log.error("Bundle Identifier not found.")
        }

        DispatchQueue.main.async {
            NotificationCenter.default.createAndPost(title: "Reset App",
                                                     message: "Please restart the app to complete the reset.",
                                                     primaryButtonTitle: "OK")
        }
    }

    func openArchiveFolder() {
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

    func reloadArchiveDocuments() {
        do {
            let archiveUrl = try PathManager.shared.getArchiveUrl()
            let untaggedUrl = try PathManager.shared.getUntaggedUrl()

            #if os(macOS)
            let untaggedFolders = [untaggedUrl, UserDefaults.observedFolderURL].compactMap { $0 }
            #else
            let untaggedFolders = [untaggedUrl]
            #endif

            archiveStore.update(archiveFolder: archiveUrl, untaggedFolders: untaggedFolders)
        } catch {
            NotificationCenter.default.postAlert(error)
        }
    }

    func updateFinderTags() {
        queue.async {
            self.archiveStore.documents
                .filter { $0.taggingStatus == .tagged }
                .forEach { document in
                    let sortedTags = Array(document.tags).sorted()
                    document.path.setFileTags(sortedTags)
                }
        }
    }

    #if os(macOS)
    func clearObservedFolder() {
        observedFolderURL = nil
        UserDefaults.observedFolderURL = nil
        queue.async {
            self.reloadArchiveDocuments()
        }
    }

    func selectObservedFolder() {
        let openPanel = NSOpenPanel()
        openPanel.title = NSLocalizedString("Choose the observed folder", comment: "")
        openPanel.showsResizeIndicator = false
        openPanel.showsHiddenFiles = false
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true
        openPanel.begin { response in
            guard response == .OK,
                  let url = openPanel.url else { return }
            self.observedFolderURL = url
            UserDefaults.observedFolderURL = url
            self.queue.async {
                self.reloadArchiveDocuments()
            }
        }
    }
    #endif
}

#if DEBUG
import Combine
import InAppPurchases
import StoreKit

extension MoreTabViewModel {
    private class MockIAPService: IAPServiceAPI {
        var productsPublisher: AnyPublisher<Set<SKProduct>, Never> {
            Just([]).eraseToAnyPublisher()
        }
        var appUsagePermitted = true
        var appUsagePermittedPublisher: AnyPublisher<Bool, Never> {
            Just(appUsagePermitted).eraseToAnyPublisher()
        }
        func buy(subscription: IAPService.SubscriptionType) throws {}
        func restorePurchases() {}
    }

    private class MockArchiveStoreAPI: ArchiveStoreAPI {
        var documents: [Document] { [] }
        var documentsPublisher: AnyPublisher<[Document], Never> {
            Just([]).eraseToAnyPublisher()
        }
        func update(archiveFolder: URL, untaggedFolders: [URL]) {}
        func archive(_ document: Document, slugify: Bool) throws {}
        func download(_ document: Document) throws {}
        func delete(_ document: Document) throws {}
        func getCreationDate(of url: URL) throws -> Date? { nil }
    }

    @State static var previewViewModel = MoreTabViewModel(iapService: MockIAPService(), archiveStore: MockArchiveStoreAPI())
}
#endif
