//
//  VisionService.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 21.02.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

//
//  VisionService.swift
//  BigBigNumbers
//
//  Created by Khoa Pham on 26.05.2018.
//  Copyright © 2018 onmyway133. All rights reserved.
//

import AVFoundation
import UIKit
import Vision

protocol VisionServiceDelegate: class {
    func visionService(_ version: VisionService, didDetect image: UIImage, results: [VNRectangleObservation])
}

final class VisionService {

    weak var delegate: VisionServiceDelegate?

    func handle(buffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else {
            return
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let image = ciImage.toUIImage() else {
            return
        }

        makeRequest(image: image)
    }

    private func inferOrientation(image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up:
            return CGImagePropertyOrientation.up
        case .upMirrored:
            return CGImagePropertyOrientation.upMirrored
        case .down:
            return CGImagePropertyOrientation.down
        case .downMirrored:
            return CGImagePropertyOrientation.downMirrored
        case .left:
            return CGImagePropertyOrientation.left
        case .leftMirrored:
            return CGImagePropertyOrientation.leftMirrored
        case .right:
            return CGImagePropertyOrientation.right
        case .rightMirrored:
            return CGImagePropertyOrientation.rightMirrored
        }
    }

    private func makeRequest(image: UIImage) {
        guard let cgImage = image.cgImage else {
            assertionFailure()
            return
        }

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: inferOrientation(image: image),
            options: [VNImageOption: Any]()
        )

        let request = VNDetectRectanglesRequest(completionHandler: { [weak self] request, error in
            DispatchQueue.main.async {
                self?.handle(image: image, request: request, error: error)
            }
        })

//        request.reportCharacterBoxes = true

        do {
            try handler.perform([request])
        } catch {
            print(error as Any)
        }
    }

    private func handle(image: UIImage, request: VNRequest, error: Error?) {

        guard let results = request.results as? [VNRectangleObservation] else { return }

        if !results.isEmpty {
            delegate?.visionService(self, didDetect: image, results: results)
        }
    }
}

extension CIImage {
    func toUIImage() -> UIImage? {
        let context = CIContext(options: nil)

        if let cgImage: CGImage = context.createCGImage(self, from: self.extent) {
            return UIImage(cgImage: cgImage)
        } else {
            return nil
        }
    }
}
