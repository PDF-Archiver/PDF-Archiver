//
//  RecentMenuSearchField.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 23.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa

class RecentMenuSearchField: NSSearchField {
    
    lazy var searchesMenu: NSMenu = {
        
        let menu = NSMenu(title: "Recents")
        
        let recentTitleItem = menu.addItem(withTitle: "Recent Searches", action: nil, keyEquivalent: "")
        recentTitleItem.tag = Int(NSSearchField.recentsTitleMenuItemTag)
        
        let placeholder = menu.addItem(withTitle: "Item", action: nil, keyEquivalent: "")
        placeholder.tag = Int(NSSearchField.recentsMenuItemTag)
        
        menu.addItem( NSMenuItem.separator() )
        
        let clearItem = menu.addItem(withTitle: "Clear Menu", action: nil, keyEquivalent: "")
        clearItem.tag = Int(NSSearchField.clearRecentsMenuItemTag)
        
        let emptyItem = menu.addItem(withTitle: "No Recent Searches", action: nil, keyEquivalent: "")
        emptyItem.tag = Int(NSSearchField.noRecentsMenuItemTag)
        
        return menu
    }()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        initialize()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }
    
    //create menu
    private func initialize() {
        self.searchMenuTemplate = searchesMenu
    }
}
