//
//  PlatformImage.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 15.06.24.
//

#if canImport(UIKit)
import UIKit.UIImage
typealias PlatformImage = UIImage
#else
import AppKit.NSImage
typealias PlatformImage = NSImage
extension NSImage {
    var cgImage: CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
#endif
