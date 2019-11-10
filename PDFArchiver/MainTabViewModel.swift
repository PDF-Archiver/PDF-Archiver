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
    @Published var shouldPresentTutorial = !UserDefaults.standard.tutorialShown

    let scanViewModel = ScanTabViewModel()
    let tagViewModel = TagTabViewModel()
    let archiveViewModel = ArchiveViewModel()

    @Published var showDocumentScan: Bool = false

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

        $shouldPresentTutorial
            .sink { shouldPresentTutorial in
                UserDefaults.standard.tutorialShown = !shouldPresentTutorial
            }
            .store(in: &disposables)

        $currentTab
            .sink { selectedIndex in
                // save the selected index for the next app start
                UserDefaults.standard.lastSelectedTabIndex = selectedIndex
                Log.send(.info, "Changed tab.", extra: ["selectedTab": String(selectedIndex)])
            }
            .store(in: &disposables)

    }
}
