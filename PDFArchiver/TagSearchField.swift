//
//  TagSearchField.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 23.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa

class TagSearchField: NSSearchField {
    override func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        print(textView.string)
        
//        NSApplication.view(<#T##NSObject#>)
//        self.update_search_field_tags(search: textView.string)
    }
    
}

