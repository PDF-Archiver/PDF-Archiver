//
//  PlatfromWrapper.swift
//  
//
//  Created by Julian Kahnert on 07.11.20.
//

#if os(macOS)
import AppKit.NSWorkspace
#else
import UIKit.UIApplication
#endif

public func open(_ url: URL) {
    #if os(macOS)
    NSWorkspace.shared.open(url)
    #else
    UIApplication.shared.open(url)
    #endif
}
