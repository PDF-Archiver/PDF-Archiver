//
//  PlatformImage.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 15.06.24.
//

#if canImport(UIKit)
import UIKit.UIImage
public typealias PlatformImage = UIImage
#else
import AppKit.NSImage
public typealias PlatformImage = NSImage
public extension NSImage {
    var cgImage: CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
#endif

extension PlatformImage {
    public func jpg(quality: CGFloat) -> Data? {
        #if os(macOS)
        // swiftlint:disable:next force_unwrapping
        let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: quality)])
        #else
        return jpegData(compressionQuality: quality)
        #endif
    }
}
