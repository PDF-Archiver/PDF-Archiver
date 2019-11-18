//
//  MainTabViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

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

    private var disposables = Set<AnyCancellable>()

    init() {

        scanViewModel.objectWillChange
            .sink { _ in
                // wait until the object has changed
                DispatchQueue.main.async {
                    self.showDocumentScan = self.scanViewModel.showDocumentScan
                }
            }
            .store(in: &disposables)

        if !UserDefaults.standard.tutorialShown {
            currentTab = 2
        }

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

        $currentTab
            .sink { selectedIndex in
                // save the selected index for the next app start
                UserDefaults.standard.lastSelectedTabIndex = selectedIndex
                Log.send(.info, "Changed tab.", extra: ["selectedTab": String(selectedIndex)])
            }
            .store(in: &disposables)

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
    }

    func showSubscriptionDismissed() {
        guard !IAP.service.appUsagePermitted() else { return }
        currentTab = 2
    }

    private func validateSubscriptionState(of selectedIndex: Int) {
        self.showSubscriptionView = !IAP.service.appUsagePermitted() && (selectedIndex == 0 || selectedIndex == 1)
    }
}
