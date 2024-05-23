//
//  MainNavigationViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable function_body_length type_body_length

import Combine
import SwiftUI
#if canImport(MessageUI)
import MessageUI
#endif

public final class MainNavigationViewModel: ObservableObject, Log {
    @Published var alertDataModel: AlertDataModel?

    @Published var currentTab: Tab? = UserDefaults.lastSelectedTab
    @Published var showTutorial = !UserDefaults.tutorialShown
    @Published var sheetType: SheetType?
    lazy var unwrappedCurrentTab: Binding<Tab> = Binding { () -> Tab in
        self.currentTab ?? .scan
    } set: { newTab in
        self.currentTab = newTab
    }

    public let imageConverter: ImageConverter
    var scanViewModel: ScanTabViewModel
    public let moreViewModel = MoreTabViewModel()

    private var disposables = Set<AnyCancellable>()

    public init() {
        imageConverter = ImageConverter(getDocumentDestination: Self.getDocumentDestination)
        scanViewModel = ScanTabViewModel(imageConverter: imageConverter)

        NotificationCenter.default.alertPublisher()
            .receive(on: DispatchQueue.main)
            .assign(to: &$alertDataModel)

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
        if !UserDefaults.tutorialShown {
            currentTab = .archive
        }

        $currentTab
            .dropFirst()
            .compactMap { $0 }
            .removeDuplicates()
            .sink { selectedTab in
                // save the selected index for the next app start
                UserDefaults.lastSelectedTab = selectedTab
                Self.log.info("Changed tab.", metadata: ["selectedTab": "\(selectedTab)"])

                FeedbackGenerator.selectionChanged()
            }
            .store(in: &disposables)

        // MARK: Intro
        $showTutorial
            .sink { shouldPresentTutorial in
                UserDefaults.tutorialShown = !shouldPresentTutorial
            }
            .store(in: &disposables)

        NotificationCenter.default.publisher(for: .introChanges)
            .sink { notification in
                self.showTutorial = (notification.object as? Bool) ?? false
            }
            .store(in: &disposables)

        imageConverter.$processedDocumentUrl
            .compactMap { $0 }
            .sink { [weak self] url in
                #if os(macOS)
                Self.showFirstDocumentFinishedDialogIfNeeded()
                #else
                if let self = self,
                   self.scanViewModel.shareDocumentAfterScan {
                    self.showShareDialog(with: url)
                } else {
                    Self.showFirstDocumentFinishedDialogIfNeeded()
                }
                #endif
            }
            .store(in: &disposables)

        DispatchQueue.global(qos: .userInteractive).async {
            self.moreViewModel.reloadArchiveDocuments()
        }
    }

    @ViewBuilder
    func getView(for sheetType: SheetType) -> some View {
        switch sheetType {
        #if canImport(MessageUI)
        case .supportView:
            SupportMailView(subject: Self.mailSubject,
                            recipients: Self.mailRecipients,
                            messagePrefix: "",
                            errorHandler: { NotificationCenter.default.postAlert($0) })
        case .supportAfterCrashView:
            SupportMailView(subject: Self.mailSubject,
                            recipients: Self.mailRecipients,
                            messagePrefix: .afterCrashMessage,
                            errorHandler: { NotificationCenter.default.postAlert($0) })
        #endif
        #if !os(macOS)
        case .activityView(let items):
            AppActivityView(activityItems: items)
        #endif
        default:
            #warning("TODO: remove this")
            EmptyView()
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

    func lazyView(for type: Tab) -> some View {
        LazyVStack {
            switch type {
                case .scan:
                    return AnyView(ScanTabView(viewModel: self.scanViewModel).keyboardShortcut("1", modifiers: .command))
                case .tag:
                    #if os(macOS)
                    return AnyView(EmptyView())
                    #else
                    return AnyView(TagTabView(viewModel: self.tagViewModel).keyboardShortcut("2", modifiers: .command))
                    #endif
                case .archive:
                    return AnyView(EmptyView())
                #if !os(macOS)
                case .more:
                    return AnyView(MoreTabView(viewModel: self.moreViewModel).keyboardShortcut("4", modifiers: .command))
                #endif
            }
        }
    }

    #warning("TODO: fix this")
    func selectedArchive(_ category: String) {
        guard let date = DateComponents(calendar: .current, timeZone: .current, year: Int(category)).date else {
            log.errorAndAssert("Could not create matching date.", metadata: ["input": "\(category)"])
            return
        }

        log.info("Tapped on archive category.")
        currentTab = .archive
//        archiveViewModel.selectedFilters = [.year(date)]
    }

    #warning("TODO: fix this")
    func selectedTag(_ category: String) {
        log.info("Tapped on tag.")
        currentTab = .archive
//        let newTagFilter: FilterItem = .tag(category)
//        if !archiveViewModel.selectedFilters.contains(newTagFilter) {
//            archiveViewModel.selectedFilters.append(newTagFilter)
//        }
    }

    func showAfterCrashSupport() {
        log.info("Show after crash support")
        sendMail(recipient: Constants.mailRecipient, subject: Constants.mailSubject, body: "App Crash 💥\n\n")
    }

    public func displayUserFeedback() {
        NotificationCenter.default.createAndPost(title: "App Crash 💥",
                                                 message: "PDF Archiver has crashed. This should not happen!\n\nPlease provide feedback, to improve the App experience.",
                                                 primaryButton: .cancel(),
                                                 secondaryButton: .default(Text("Send"),
                                                                           action: showAfterCrashSupport))
    }

    #if !os(macOS)
    public func showScan(shareAfterScan: Bool) {
        withAnimation {
            currentTab = .scan
            scanViewModel.shareDocumentAfterScan = shareAfterScan
            scanViewModel.startScanning()
        }
    }
    #endif

    // MARK: - Delegate Functions

    private static func getDocumentDestination() -> URL? {
        do {
            return try PathManager.shared.getUntaggedUrl()
        } catch {
            NotificationCenter.default.postAlert(error)
            return nil
        }
    }

    // MARK: - Helper Functions

    private static func showFirstDocumentFinishedDialogIfNeeded() {
        guard !UserDefaults.firstDocumentScanAlertPresented else { return }
        UserDefaults.firstDocumentScanAlertPresented = true

        NotificationCenter.default.createAndPost(title: "First Scan processed! 🙂",
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
            try? FileManager.default.removeItem(at: url)

            NotificationCenter.default.postAlert(error)
        }
    }

    #if !os(macOS)
    private func showShareDialog(with url: URL) {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("dd-MM-yyyy jmmssa")
        let dateString = formatter.string(from: Date()).replacingOccurrences(of: ":", with: ".").replacingOccurrences(of: ",", with: "")
        let filename = "PDF Archiver \(dateString).pdf"
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try FileManager.default.copyItem(at: url, to: destination)

            self.sheetType = .activityView(items: [destination])
        } catch {
            NotificationCenter.default.postAlert(error)
        }
    }
    #endif
}

extension MainNavigationViewModel {
    enum SheetType: Identifiable {
        #if !os(macOS)
        case activityView(items: [Any])
        #endif

        var id: String {
            switch self {
                #if canImport(MessageUI)
                case .supportView:
                    return "supportView"
                case .supportAfterCrashView:
                    return "supportAfterCrashView"
                #endif
                #if !os(macOS)
                case .activityView:
                    return "activityView"
                #endif
            }
        }
    }
}
