//
//  KeyCon.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 27.02.20.
//  Copyright © 2020 Julian Kahnert. All rights reserved.
//

import SwiftUI

class KeyCommandHostingController<Content>: UIHostingController<Content> where Content: View {

    private let viewModel: MainTabViewModel

    // global shortcuts
    private let tab0 = UIKeyCommand(title: "Open Scan Tab", action: #selector(action), input: "1", modifierFlags: .command, discoverabilityTitle: "Open the Scan tab")
    private let tab1 = UIKeyCommand(title: "Open Tag Tab", action: #selector(action), input: "2", modifierFlags: .command, discoverabilityTitle: "Open the Tag tab")
    private let tab2 = UIKeyCommand(title: "Open Archive Tab", action: #selector(action), input: "3", modifierFlags: .command, discoverabilityTitle: "Open the Archive tab")
    private let tab3 = UIKeyCommand(title: "Open More Tab", action: #selector(action), input: "4", modifierFlags: .command, discoverabilityTitle: "Open the More tab")

    // document tab shortcuts
    private let save = UIKeyCommand(title: "Save", action: #selector(action), input: "s", modifierFlags: .command, discoverabilityTitle: "Save current document")
    private let delete = UIKeyCommand(title: "Delete", action: #selector(action), input: "\u{8}", modifierFlags: .command, discoverabilityTitle: "Delete current document")

    init(rootView: Content, viewModel: MainTabViewModel) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func becomeFirstResponder() -> Bool {
        true
    }

    override var keyCommands: [UIKeyCommand]? {
        var commands = [tab0, tab1, tab2, tab3]
        if viewModel.currentTab == 1 {
            commands.append(contentsOf: [save, delete])
        }
        commands.forEach { command in
            command.title = command.title.localized
            command.discoverabilityTitle = command.discoverabilityTitle?.localized
        }
        return commands
    }

    @objc
    func action(_ sender: UIKeyCommand) {
        switch sender {
        case save:
            guard viewModel.currentTab == 1 else {
                assertionFailure("Could not save document in tab #\(viewModel.currentTab)")
                return
            }
            viewModel.tagViewModel.saveDocument()
        case delete:
            guard viewModel.currentTab == 1 else {
                assertionFailure("Could not save document in tab #\(viewModel.currentTab)")
                return
            }
            viewModel.tagViewModel.deleteDocument()
        case tab0:
            viewModel.currentTab = 0
        case tab1:
            viewModel.currentTab = 1
        case tab2:
            viewModel.currentTab = 2
        case tab3:
            viewModel.currentTab = 3
        default:
            print(">>> test was pressed")
        }
    }
}
