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

extension PlatformImage {
    func jpg(quality: CGFloat) -> Data? {
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
