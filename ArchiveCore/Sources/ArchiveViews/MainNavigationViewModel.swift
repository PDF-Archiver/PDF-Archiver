//
//  MainNavigationViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable function_body_length

import ArchiveBackend
import Combine
import SwiftUI
#if canImport(MessageUI)
import MessageUI
#endif

public final class MainNavigationViewModel: ObservableObject, Log {

    public static let archiveStore = ArchiveStore.shared
    public static let iapService = IAPService()
    static let mailRecipients = ["support@pdf-archiver.io"]
    static let mailSubject = "PDF Archiver: iOS Support"

    @Published var error: Error?

    @Published var archiveCategories: [String] = []
    @Published var tagCategories: [String] = []

    @Published var currentTab: Tab = UserDefaults.appGroup.lastSelectedTab
    @Published var currentOptionalTab: Tab?
    @Published var showTutorial = !UserDefaults.appGroup.tutorialShown
    @Published var isShowingMailView: Bool = false
    #if canImport(MessageUI)
    @Published var result: Result<MFMailComposeResult, Error>?
    #endif

    public private(set) lazy var imageConverter = ImageConverter(getDocumentDestination: getDocumentDestination)

    lazy var scanViewModel = ScanTabViewModel(imageConverter: imageConverter, iapService: Self.iapService, documentsFinishedHandler: Self.scanFinished)
    let tagViewModel = TagTabViewModel()
    let archiveViewModel = ArchiveViewModel()
    public private(set) lazy var moreViewModel = MoreTabViewModel(iapService: Self.iapService, archiveStore: Self.archiveStore)

    let iapViewModel = IAPViewModel(iapService: iapService)

    @Published var showSubscriptionView: Bool = false

    private var disposables = Set<AnyCancellable>()

    func getDocumentDestination() -> URL? {
        do {
            return try PathManager.shared.getUntaggedUrl()
        } catch {
            self.error = error
            return nil
        }
    }

    public init() {

        Self.iapService.$error
            .assign(to: &$error)

        imageConverter.$error
            .assign(to: &$error)

        $currentTab
            .map { Optional($0) }
            .removeDuplicates()
            .assign(to: &$currentOptionalTab)

        $currentOptionalTab
            .compactMap { $0 }
            .removeDuplicates()
            .assign(to: &$currentTab)

        scanViewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { _ in
                // bubble up the change from the nested view model
                self.objectWillChange.send()
            }
            .store(in: &disposables)

        // No need to add a 'tagViewModel.objectWillChange' publisher, because the MainNavigationView does not need to handle changes
        // only the TagTabView must do so.

        // MARK: UserDefaults
        if !UserDefaults.appGroup.tutorialShown {
            currentTab = .archive
        }

        $currentTab
            .dropFirst()
            .removeDuplicates()
            .sink { selectedTab in
                // save the selected index for the next app start
                UserDefaults.appGroup.lastSelectedTab = selectedTab
                Self.log.info("Changed tab.", metadata: ["selectedTab": "\(selectedTab)"])

                FeedbackGenerator.selectionChanged()
            }
            .store(in: &disposables)

        // MARK: Intro
        $showTutorial
            .sink { shouldPresentTutorial in
                UserDefaults.appGroup.tutorialShown = !shouldPresentTutorial
            }
            .store(in: &disposables)

        NotificationCenter.default.publisher(for: .introChanges)
            .sink { notification in
                self.showTutorial = (notification.object as? Bool) ?? false
            }
            .store(in: &disposables)

        // MARK: Subscription
        Self.iapService.appUsagePermittedPublisher
            // do not use initial value -> finish validation first
            .dropFirst()
            .removeDuplicates()
            .combineLatest($currentTab)
            .receive(on: DispatchQueue.main)
            .sink { (_, selectedTab) in
                self.showSubscriptionView = !Self.iapService.appUsagePermitted && selectedTab == .tag
            }
            .store(in: &disposables)

        NotificationCenter.default.publisher(for: .showSubscriptionView)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                self.showSubscriptionView = true
            }
            .store(in: &disposables)

        NotificationCenter.default.publisher(for: .showSendDiagnosticsReport)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                self.showSupport()
            }
            .store(in: &disposables)

        Self.archiveStore.$years
            .map { years -> [String] in
                let tmp = years.sorted()
                    .reversed()
                    .prefix(5)

                return Array(tmp)
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &self.$archiveCategories)

        Self.archiveStore.$documents
            .map { _ in
                Array(TagStore.shared.getSortedTags().prefix(10).map(\.localizedCapitalized))
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &self.$tagCategories)

        // TODO: change container!?
        DispatchQueue.global(qos: .userInteractive).async {
            // TODO: handle no icloud drive found
            do {
                let archiveUrl = try PathManager.shared.getArchiveUrl()
                let untaggedUrl = try PathManager.shared.getUntaggedUrl()

                Self.archiveStore.update(archiveFolder: archiveUrl, untaggedFolders: [untaggedUrl])
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                }
            }
        }
    }

    func handleTempFilesIfNeeded(_ scenePhase: ScenePhase) {
        guard scenePhase == .active else { return }

        // get documents from ShareExtension and AppClip
        let extensionURLs = (try? FileManager.default.contentsOfDirectory(at: PathConstants.extensionTempPdfURL, includingPropertiesForKeys: [], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])) ?? []
        let appClipURLs = (try? FileManager.default.contentsOfDirectory(at: PathConstants.appClipTempPdfURL, includingPropertiesForKeys: [], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])) ?? []
        let urls = [extensionURLs, appClipURLs]
            .flatMap { $0 }
            .filter { !$0.hasDirectoryPath }

        if !urls.isEmpty {
            DispatchQueue.main.async {

                // show scan tab with document processing, after importing a document
                self.currentTab = .scan
            }
        }

        for url in urls {
            self.handle(url: url)
        }
    }

    func view(for type: Tab) -> AnyView {
        switch type {
            case .scan:
                return AnyView(ScanTabView(viewModel: scanViewModel))
            case .tag:
                #if os(macOS)
                return AnyView(TagTabViewMac(viewModel: tagViewModel))
                #else
                return AnyView(TagTabView(viewModel: tagViewModel))
                #endif
            case .archive:
                return AnyView(ArchiveView(viewModel: archiveViewModel))
            #if !os(macOS)
            case .more:
                return AnyView(MoreTabView(viewModel: moreViewModel))
            #endif
        }
    }

    func selectedArchive(_ category: String) {
        guard let date = DateComponents(calendar: .current, timeZone: .current, year: Int(category)).date else {
            log.errorAndAssert("Could not create matching date.", metadata: ["input": "\(category)"])
            return
        }

        log.info("Tapped on archive category.")
        currentTab = .archive
        archiveViewModel.selectedFilters = [.year(date)]
    }

    func selectedTag(_ category: String) {
        log.info("Tapped on tag.")
        currentTab = .archive
        let newTagFilter: FilterItem = .tag(category)
        if !archiveViewModel.selectedFilters.contains(newTagFilter) {
            archiveViewModel.selectedFilters.append(newTagFilter)
        }
    }

    func handleIAPViewDismiss() {
        guard !Self.iapService.appUsagePermitted else { return }
        currentTab = .scan
    }

    func showSupport() {
        log.info("Show support")
        #if os(macOS)
        sendDiagnosticsReport()
        #else
        if MFMailComposeViewController.canSendMail() {
            isShowingMailView = true
        } else {
            guard let url = URL(string: "https://pdf-archiver.io/faq") else { preconditionFailure("Could not generate the FAQ url.") }
            open(url)
        }
        #endif
    }

    // MARK: - Helper Functions

    private static func scanFinished(error: inout Error?) {
        guard !UserDefaults.appGroup.firstDocumentScanAlertPresented else { return }
        UserDefaults.appGroup.firstDocumentScanAlertPresented = true

        error = AlertDataModel.createAndPost(title: "First Scan processed! 🙂",
                                                  message: "The first document was processed successfully and is now waiting for you in the 'Tag' tab.\n\n📄   ➡️   🗄",
                                                  primaryButtonTitle: "OK")
    }

    private func handle(url: URL) {
        log.info("Handling shared document", metadata: ["filetype": "\(url.pathExtension)"])

        do {
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            _ = url.startAccessingSecurityScopedResource()
            try imageConverter.handle(url)
        } catch {
            log.error("Unable to handle file.", metadata: ["filetype": "\(url.pathExtension)", "error": "\(error)"])
//            try? FileManager.default.removeItem(at: url)

            DispatchQueue.main.async {
                self.error = error
            }
        }
    }
}

#if os(macOS)
import AppKit
import Diagnostics

extension MainNavigationViewModel {
    func sendDiagnosticsReport() {
        // add a diagnostics report
        var reporters = DiagnosticsReporter.DefaultReporter.allReporters
        reporters.insert(CustomDiagnosticsReporter.self, at: 1)
        let report = DiagnosticsReporter.create(using: reporters)

        guard let service = NSSharingService(named: .composeEmail) else {
            log.errorAndAssert("Failed to get sharing service.")

            guard let url = URL(string: "https://pdf-archiver.io/faq") else { preconditionFailure("Could not generate the FAQ url.") }
            open(url)
            return
        }
        service.recipients = Self.mailRecipients
        service.subject = Self.mailSubject

        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Diagnostics-Report.html")

        // remove previous report
        try? FileManager.default.removeItem(at: url)

        do {
            try report.data.write(to: url)
        } catch {
            preconditionFailure("Failed with error: \(error)")
        }

        service.perform(withItems: [url])
    }
}
#endif
