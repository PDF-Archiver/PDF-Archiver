//
//  MainTabViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable function_body_length

import Combine
import SwiftUI

class MainTabViewModel: ObservableObject {
    @Published var currentTab = UserDefaults.standard.lastSelectedTabIndex
    @Published var showTutorial = !UserDefaults.standard.tutorialShown

    let scanViewModel = ScanTabViewModel()
    let tagViewModel = TagTabViewModel()
    let archiveViewModel = ArchiveViewModel()
    let moreViewModel = MoreTabViewModel()

    let iapViewModel = IAPViewModel()

    @Published var showDocumentScan: Bool = false
    @Published var showSubscriptionView: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertViewModel: AlertViewModel?

    private var disposables = Set<AnyCancellable>()
    private let selectionFeedback = UISelectionFeedbackGenerator()

    init() {

        scanViewModel.objectWillChange
            .sink { _ in
                // wait until the object has changed
                DispatchQueue.main.async {
                    self.showDocumentScan = self.scanViewModel.showDocumentScan
                }
            }
            .store(in: &disposables)

        // MARK: UserDefaults
        if !UserDefaults.standard.tutorialShown {
            currentTab = 2
        }

        $currentTab
            .dropFirst()
            .removeDuplicates()
            .sink { selectedIndex in
                // save the selected index for the next app start
                UserDefaults.standard.lastSelectedTabIndex = selectedIndex
                Log.send(.info, "Changed tab.", extra: ["selectedTab": String(selectedIndex)])

                self.selectionFeedback.prepare()
                self.selectionFeedback.selectionChanged()
            }
            .store(in: &disposables)

        // MARK: Intro
        $showTutorial
            .sink { shouldPresentTutorial in
                UserDefaults.standard.tutorialShown = !shouldPresentTutorial
            }
            .store(in: &disposables)

        NotificationCenter.default.publisher(for: .introChanges)
            .sink { notification in
                self.showTutorial = (notification.object as? Bool) ?? false
            }
            .store(in: &disposables)

        // MARK: Subscription
        $currentTab
            .sink { selectedIndex in
                self.validateSubscriptionState(of: selectedIndex)
            }
            .store(in: &disposables)

        NotificationCenter.default.publisher(for: .subscriptionChanges)
            .sink { _ in
                self.showSubscriptionDismissed()
                self.validateSubscriptionState(of: self.currentTab)
            }
            .store(in: &disposables)
        
        NotificationCenter.default.publisher(for: .showSubscriptionView)
        .sink { _ in
            self.showSubscriptionView = true
        }
        .store(in: &disposables)

        // MARK: Alerts
        $alertViewModel
            .receive(on: DispatchQueue.main)
            .sink { viewModel in
                self.showAlert = viewModel != nil
            }
            .store(in: &disposables)

        NotificationCenter.default.publisher(for: .showError)
            .sink { notification in
                self.alertViewModel = notification.object as? AlertViewModel
            }
            .store(in: &disposables)
    }

    func showSubscriptionDismissed() {
        guard !IAP.service.appUsagePermitted() && currentTab == 1 else { return }
        currentTab = 2
    }

    private func validateSubscriptionState(of selectedIndex: Int) {
        self.showSubscriptionView = !IAP.service.appUsagePermitted() && selectedIndex == 1
    }
}
