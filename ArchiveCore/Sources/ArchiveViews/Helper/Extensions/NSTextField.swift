//
//  NSTextField.swift
//  
//
//  Created by Julian Kahnert on 28.11.20.
//

#if os(macOS)
import AppKit

extension NSTextField {

    // disables the focues ring for all macOS textfields
    open override var focusRingType: NSFocusRingType {
        get { .none }
        set { }
    }
}
#endif
