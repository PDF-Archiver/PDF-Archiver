//
//  PlatformImage.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.26.
//

import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit.UIImage

typealias PlatformImage = UIImage

extension UIImage {
    convenience init?(contentsOf url: URL) {
        self.init(contentsOfFile: url.path())
    }
}
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
    static func from(_ cgImage: CGImage) -> PlatformImage {
        #if canImport(UIKit)
        UIImage(cgImage: cgImage)
        #else
        NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #endif
    }

    func jpg(quality: CGFloat) -> Data? {
        #if os(macOS)
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: quality)])
        #else
        return jpegData(compressionQuality: quality)
        #endif
    }
}
