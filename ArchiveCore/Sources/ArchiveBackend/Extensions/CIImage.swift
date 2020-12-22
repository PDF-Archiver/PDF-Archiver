//
//  CIImage.swift
//  
//
//  Created by Julian Kahnert on 06.11.20.
//

#if os(macOS)
import AppKit
#else
import UIKit.UIImage
#endif

extension CIImage {
    func jpegData(compressionQuality quality: CGFloat) -> Data? {
        #if os(macOS)
        let bitmapRep = NSBitmapImageRep(ciImage: self)
        let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: Float(quality))])

        return jpegData
        #else
        return UIImage(ciImage: self).jpegData(compressionQuality: quality)
        #endif
    }
}
