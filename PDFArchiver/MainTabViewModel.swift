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

    @Published var scanViewModel = ScanTabViewModel()
    @Published var tagViewModel = TagTabViewModel()
    @Published var archiveViewModel = ArchiveViewModel()

    private var disposables = Set<AnyCancellable>()

    init() {

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
