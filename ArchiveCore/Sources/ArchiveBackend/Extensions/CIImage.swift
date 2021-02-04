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
extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
            case .up: self = .up
            case .upMirrored: self = .upMirrored
            case .down: self = .down
            case .downMirrored: self = .downMirrored
            case .left: self = .left
            case .leftMirrored: self = .leftMirrored
            case .right: self = .right
            case .rightMirrored: self = .rightMirrored
            @unknown default:
                fatalError("Orientation unkown")
        }
    }
}
#endif

extension CIImage {

    #if !os(macOS)
    /// Creates a `CIImage` and preserve the image orientation.
    ///
    /// The `CIImage(image: )` initializer does uses the current orientation of the `UIImage`, we fix this be applying a new orientation property.
    /// Source: https://stackoverflow.com/a/61849964/10026834
    ///
    /// - Parameter image: Images with an orientation.
    public convenience init?(imageWithOrientation image: UIImage) {
        self.init(image: image,
                options: [
                    .applyOrientationProperty: true,
                    .properties: [kCGImagePropertyOrientation: CGImagePropertyOrientation(image.imageOrientation).rawValue]
                ])
    }
    #endif

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
